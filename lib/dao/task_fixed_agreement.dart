import 'package:money2/money2.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../entity/entity.g.dart';
import '../util/dart/exceptions.dart';
import 'billing_mutation.dart';
import 'dao.dart';

/// Records an in-person fixed addition without requiring a quotation workflow.
class TaskFixedAgreement {
  Future<Map<String, Object?>?> get(int taskId) async {
    final rows = await DatabaseHelper.instance.database.query(
      'task_fixed_agreement',
      where: 'task_id = ?',
      whereArgs: [taskId],
    );
    return rows.firstOrNull;
  }

  Future<void> save(
    Transaction txn,
    Task task,
    Money amount,
    String note,
  ) async {
    if (task.billingType != BillingType.fixedPrice || !amount.isPositive) {
      throw InvoiceException('An agreed fixed task needs a positive price.');
    }
    final old = await txn.query(
      'task_fixed_agreement',
      where: 'task_id = ?',
      whereArgs: [task.id],
    );
    if (old.isNotEmpty &&
        old.single['amount'] == amount.minorUnits.toInt() &&
        old.single['agreement_note'] == note.trim()) {
      return;
    }
    if (old.isNotEmpty) {
      final claims = await txn.query(
        'billing_allocation',
        where:
            'source_type = ? AND source_id = ? AND '
            '(released_date IS NULL OR EXISTS '
            '(SELECT 1 FROM invoice i '
            'WHERE i.id = billing_allocation.invoice_id))',
        whereArgs: ['task_scope', old.single['id']],
      );
      if (claims.isNotEmpty) {
        throw InvoiceException(
          'This agreement has invoice history. Add a new variation task.',
        );
      }
    }
    final billed = await txn.rawQuery(
      '''
SELECT id FROM time_entry WHERE task_id = ? AND billed = 1
UNION ALL SELECT id FROM task_item WHERE task_id = ? AND billed = 1
UNION ALL SELECT g.id FROM quote_line_group g JOIN quote q ON q.id = g.quote_id
 WHERE g.task_id = ? AND q.state IN ('approved', 'invoiced')
 AND g.line_approval_status != 'rejected'
LIMIT 1
''',
      [task.id, task.id, task.id],
    );
    if (billed.isNotEmpty) {
      throw InvoiceException(
        'This work is already quoted or invoiced. Add a new variation task.',
      );
    }
    final now = DateTime.now().toIso8601String();
    final values = <String, Object?>{
      'task_id': task.id,
      'job_id': task.jobId,
      'amount': amount.minorUnits.toInt(),
      'agreement_note': note.trim(),
      'agreed_date': now,
      'modified_date': now,
    };
    if (old.isEmpty) {
      values['created_date'] = now;
      await txn.insert('task_fixed_agreement', values);
    } else {
      await txn.update(
        'task_fixed_agreement',
        values,
        where: 'id = ?',
        whereArgs: [old.single['id']],
      );
    }
    await BillingMutation.enqueue(txn, {task.jobId});
  }
}
