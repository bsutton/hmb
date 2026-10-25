import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:money2/money2.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:uuid/uuid.dart';

import '../entity/entity.g.dart';
import '../fsm/lifecycle_event_dispatcher.dart';
import '../fsm/lifecycle_models.dart';
import '../fsm/quote_events.dart';
import '../util/dart/app_settings.dart';
import '../util/dart/exceptions.dart';
import '../util/dart/format.dart';
import '../util/dart/local_date.dart';
import '../util/dart/money_ex.dart';
import 'billing_mutation.dart';
import 'billing_waiver.dart';
import 'dao.g.dart';
import 'job_billing_contact.dart';

/// A whole-source charge. Its identity is stable across previews and retries.
class BillingCandidate {
  final String kind;
  final int sourceId;
  final int? taskId;
  final int? quoteId;
  final String description;
  final String group;
  final Money amount;
  final Fixed quantity;
  final Money unitPrice;
  final LocalDate? billingDate;
  final Object version;

  BillingCandidate({
    required this.kind,
    required this.sourceId,
    required this.description,
    required this.group,
    required this.amount,
    required this.version,
    this.taskId,
    this.quoteId,
    this.billingDate,
    Fixed? quantity,
    Money? unitPrice,
  }) : quantity = quantity ?? Fixed.one,
       unitPrice = unitPrice ?? amount;

  String get key => '$kind:$sourceId';
  String get waiverHash => _digest(signature);
  bool get isFuture =>
      kind == 'milestone' &&
      billingDate != null &&
      billingDate!.toDateTime().isAfter(LocalDate.today().toDateTime());
  Map<String, Object?> get signature => {
    'key': key,
    'amount': amount.minorUnits.toInt(),
    'version': version,
    'description': description,
    'quantity': quantity.toString(),
    'unitPrice': unitPrice.minorUnits.toInt(),
  };
}

class BillingPreview {
  final Job job;
  final List<BillingCandidate> candidates;
  final List<String> blocked;
  final List<Contact> contacts;
  final int? defaultContactId;
  final String fingerprint;
  final int paymentTerms;
  final String billingCustomerName;
  final int? billingCustomerId;
  final double taxRate;
  final List<BillingWaiver> waivers;

  /// Quote coverage is separate from the flag for a standalone fee invoice.
  final Map<String, bool> bookingFeeQuotes;
  final Money? effectiveBookingFee;
  const BillingPreview({
    required this.job,
    required this.candidates,
    required this.blocked,
    required this.contacts,
    required this.defaultContactId,
    required this.fingerprint,
    required this.paymentTerms,
    required this.billingCustomerName,
    required this.billingCustomerId,
    required this.taxRate,
    this.waivers = const [],
    this.bookingFeeQuotes = const {},
    this.effectiveBookingFee,
  });

  Money includedTax(Iterable<BillingCandidate> selected) => selected.fold(
    MoneyEx.zero,
    (total, charge) => total + _includedTax(charge.amount, taxRate),
  );

  InvoicePlan select({
    required Iterable<String> keys,
    required int contactId,
    bool groupByTask = true,
    bool allowEarlyBilling = false,
    LocalDate? dueDate,
  }) {
    final selected = keys.toSet();
    if (selected.isEmpty ||
        selected.length != keys.length ||
        !selected.every((key) => candidates.any((c) => c.key == key))) {
      throw InvoiceException('Select available charges once each.');
    }
    if (billingCustomerId == null) {
      throw InvoiceException('Select the Bill to customer before invoicing.');
    }
    if (!contacts.any((c) => c.id == contactId)) {
      throw InvoiceException('Select a contact for the Bill to customer.');
    }
    final charges = candidates.where((c) => selected.contains(c.key)).toList();
    if (charges
        .fold(MoneyEx.zero, (total, charge) => total + charge.amount)
        .isNegative) {
      throw InvoiceException(
        'Use a credit note for a net credit to the customer.',
      );
    }
    if (!allowEarlyBilling && charges.any((c) => c.isFuture)) {
      throw InvoiceException('Confirm early billing for future milestones.');
    }
    return InvoicePlan(
      id: const Uuid().v4(),
      preview: this,
      charges: List.unmodifiable(charges),
      contactId: contactId,
      groupByTask: groupByTask,
      allowEarlyBilling: allowEarlyBilling,
      dueDate: dueDate ?? LocalDate.today().add(Duration(days: paymentTerms)),
    );
  }
}

class InvoicePlan {
  final String id;
  final BillingPreview preview;
  final List<BillingCandidate> charges;
  final int contactId;
  final bool groupByTask;
  final bool allowEarlyBilling;
  final LocalDate dueDate;
  const InvoicePlan({
    required this.id,
    required this.preview,
    required this.charges,
    required this.contactId,
    required this.groupByTask,
    required this.allowEarlyBilling,
    required this.dueDate,
  });
  Money get total => charges.fold(MoneyEx.zero, (sum, c) => sum + c.amount);
  String get fingerprint => _digest([
    preview.fingerprint,
    contactId,
    charges.map((c) => c.key).toList(),
    groupByTask,
    allowEarlyBilling,
    dueDate.toDateTime().toIso8601String(),
  ]);
}

String _digest(Object value) =>
    sha256.convert(utf8.encode(jsonEncode(value))).toString();

Money _includedTax(Money gross, double rate) =>
    MoneyEx.fromInt((gross.minorUnits.toInt() * rate / (100 + rate)).round());

/// Every entry point uses this preview, revalidation and atomic commit path.
class BillingService {
  Database get _db => DatabaseHelper.instance.database;

  Future<BillingPreview> preview(
    int jobId, {
    bool forEligibility = false,
  }) async {
    final config = await _BillingConfig.load(pricing: !forEligibility);
    return await _db.transaction((txn) => _preview(txn, jobId, config));
  }

  Future<BillingPreview> _preview(
    Transaction db,
    int jobId,
    _BillingConfig config,
  ) async {
    final job = await DaoJob().getById(jobId, db);
    if (job == null || job.isStock || job.status == JobStatus.rejected) {
      throw InvoiceException('This job is not available for invoicing.');
    }
    final contacts = await billingContactsForCustomer(
      job.billingCustomerId,
      db,
    );
    final resolved = (await resolveJobBillingContact(job, db)).contact;
    if (resolved != null && !contacts.any((c) => c.id == resolved.id)) {
      contacts.add(resolved);
    }
    final candidates = <BillingCandidate>[];
    final blocked = <String>[];
    final customer = await DaoCustomer().getById(job.billingCustomerId, db);
    final versions = <Object>[
      job.toMap(),
      config.signature,
      contacts.map((c) => c.toMap()).toList(),
      if (customer != null) customer.toMap(),
    ];
    final waiverRows = await db.query(
      'billing_waiver',
      where: 'job_id = ?',
      whereArgs: [jobId],
      orderBy: 'id DESC',
    );
    final waivers = waiverRows.map(BillingWaiver.fromMap).toList();
    versions.add(waiverRows);
    final claims = await db.rawQuery(
      '''
SELECT a.* FROM billing_allocation a JOIN invoice i ON i.id = a.invoice_id
WHERE i.job_id = ? AND a.released_date IS NULL
''',
      [jobId],
    );
    final claimed = claims
        .map((r) => '${r['source_type']}:${r['source_id']}')
        .toSet();
    versions.add(claims);
    void add(BillingCandidate c) {
      final waived = waivers.any(
        (waiver) =>
            waiver.restoredDate == null &&
            waiver.sourceKey == c.key &&
            waiver.sourceHash == c.waiverHash,
      );
      if (!claimed.contains(c.key) && !waived) {
        candidates.add(c);
      }
    }

    final quotes = await db.query(
      'quote',
      where: 'job_id = ?',
      whereArgs: [jobId],
      orderBy: 'id',
    );
    versions.add(quotes);
    final covered = <int, int>{};
    final overlaps = <int>{};
    final agreements = await db.query(
      'task_fixed_agreement',
      where: 'job_id = ?',
      whereArgs: [jobId],
      orderBy: 'id',
    );
    versions.add(agreements);
    final agreedTasks = agreements.map((a) => a['task_id']! as int).toSet();
    var quotedFee = false;
    final quotesWithFee = <int>{};
    final bookingFeeQuotes = <String, bool>{};
    final feeLines = await db.rawQuery(
      '''
SELECT l.id FROM invoice_line l JOIN invoice i ON i.id = l.invoice_id
WHERE i.job_id = ? AND l.from_booking_fee = 1
AND NOT EXISTS (SELECT 1 FROM billing_allocation a
 WHERE a.invoice_line_id = l.id AND a.source_type = 'booking_fee'
 AND a.released_date IS NOT NULL)
''',
      [jobId],
    );
    versions.add(feeLines);
    final approved = quotes
        .where((q) => q['state'] == 'approved' || q['state'] == 'invoiced')
        .toList();
    final groupsByQuote = <int, List<Map<String, Object?>>>{};
    for (final row in approved) {
      final id = row['id']! as int;
      final groups = await db.query(
        'quote_line_group',
        where: 'quote_id = ? AND line_approval_status != ?',
        whereArgs: [id, 'rejected'],
        orderBy: 'id',
      );
      groupsByQuote[id] = groups;
      versions.add(groups);
      for (final group in groups) {
        if (group['task_id'] case final int taskId) {
          if (agreedTasks.contains(taskId)) {
            overlaps.add(id);
          }
          final previous = covered[taskId];
          if (previous != null && previous != id) {
            overlaps.addAll([previous, id]);
          }
          covered[taskId] = id;
        } else if ((group['name']! as String).toLowerCase().contains(
          'booking',
        )) {
          quotedFee = true;
          quotesWithFee.add(id);
        }
      }
    }
    for (final row in approved) {
      final quote = Quote.fromMap(row);
      final groups = groupsByQuote[quote.id]!;
      final milestones = (await db.query(
        'milestone',
        where: 'quote_id = ? AND voided = 0',
        whereArgs: [quote.id],
        orderBy: 'milestone_number',
      )).map(Milestone.fromMap).toList();
      versions.add(milestones.map((m) => m.toMap()).toList());
      if (quotesWithFee.contains(quote.id)) {
        bookingFeeQuotes[quote.bestNumber] =
            claimed.contains('quote:${quote.id}') ||
            (milestones.isNotEmpty &&
                milestones.every((milestone) => milestone.invoiceId != null) &&
                milestones.fold(
                      MoneyEx.zero,
                      (sum, milestone) => sum + milestone.paymentAmount,
                    ) ==
                    quote.totalAmount);
      }
      if (claimed.contains('quote:${quote.id}')) {
        continue;
      }
      if (quote.state.name == 'invoiced') {
        final hasOpenMilestones = milestones.any((m) => m.invoiceId == null);
        final fullyInvoicedMilestones =
            milestones.isNotEmpty &&
            !hasOpenMilestones &&
            milestones.fold(MoneyEx.zero, (sum, m) => sum + m.paymentAmount) ==
                quote.totalAmount;
        // Retain released allocations as evidence that modern work can be
        // re-billed. A legacy 'invoiced' state alone may mean partial billing.
        final allocations = await db.rawQuery(
          '''
SELECT a.id FROM billing_allocation a
LEFT JOIN milestone m ON a.source_type = 'milestone' AND m.id = a.source_id
WHERE (a.source_type = 'quote' AND a.source_id = ?) OR m.quote_id = ? LIMIT 1
''',
          [quote.id, quote.id],
        );
        if (fullyInvoicedMilestones) {
          continue;
        }
        if (!milestones.any((m) => m.invoiceId != null) &&
            allocations.isEmpty) {
          blocked.add(
            'Quote #${quote.bestNumber}: review historical billing '
            'before charging again.',
          );
          continue;
        }
      }
      if (quotesWithFee.contains(quote.id) &&
          (job.bookingFeeInvoiced || feeLines.isNotEmpty)) {
        blocked.add(
          'Quote #${quote.bestNumber}: review its booking fee, '
          'which has already been invoiced separately.',
        );
        continue;
      }
      final lines = await db.query(
        'quote_line',
        where: 'quote_id = ?',
        whereArgs: [quote.id],
        orderBy: 'id',
      );
      versions.add(lines);
      if (lines.isNotEmpty) {
        final acceptedGroups = groups.map((g) => g['id']).toSet();
        final acceptedAmount = lines
            .where(
              (line) =>
                  line['line_chargeable_status'] == 'normal' &&
                  (line['quote_line_group_id'] == null ||
                      acceptedGroups.contains(line['quote_line_group_id'])),
            )
            .fold(
              MoneyEx.zero,
              (sum, line) => sum + MoneyEx.fromInt(line['line_total']! as int),
            );
        if (acceptedAmount != quote.totalAmount) {
          blocked.add(
            'Quote #${quote.bestNumber}: reconcile the agreed total '
            'with its accepted lines.',
          );
          continue;
        }
      }
      if (!quote.totalAmount.isPositive) {
        continue;
      }
      if (overlaps.contains(quote.id)) {
        blocked.add(
          'Quote #${quote.bestNumber}: resolve overlapping approved tasks.',
        );
        continue;
      }
      // Legacy scope may already have been billed by the old task engine.
      final taskIds = groups.map((g) => g['task_id']).whereType<int>().toList();
      var previouslyBilled = false;
      for (final taskId in taskIds) {
        final old = await db.rawQuery(
          '''
SELECT id FROM task_item WHERE task_id = ? AND billed = 1
UNION ALL SELECT id FROM time_entry WHERE task_id = ? AND billed = 1
LIMIT 1
''',
          [taskId, taskId],
        );
        previouslyBilled |= old.isNotEmpty;
      }
      if (previouslyBilled) {
        blocked.add(
          'Quote #${quote.bestNumber}: review work already invoiced '
          'as actual charges.',
        );
        continue;
      }
      final allocated = milestones.fold(
        MoneyEx.zero,
        (sum, m) => sum + m.paymentAmount,
      );
      if (allocated > quote.totalAmount) {
        blocked.add(
          'Quote #${quote.bestNumber}: milestones exceed the agreed total.',
        );
        continue;
      }
      if (milestones.isEmpty) {
        add(
          BillingCandidate(
            kind: 'quote',
            sourceId: quote.id,
            quoteId: quote.id,
            description: 'Final payment: ${quote.summary}',
            group: 'Fixed payments',
            amount: quote.totalAmount,
            version: [row, groups, lines],
          ),
        );
      } else {
        for (final milestone in milestones) {
          if (milestone.invoiceId == null &&
              milestone.paymentAmount.isNonZero) {
            add(
              BillingCandidate(
                kind: 'milestone',
                sourceId: milestone.id,
                quoteId: quote.id,
                description:
                    milestone.milestoneDescription ??
                    'Quote #${quote.bestNumber}, '
                        'milestone ${milestone.milestoneNumber}',
                group: 'Fixed payments',
                amount: milestone.paymentAmount,
                billingDate: milestone.dueDate,
                version: milestone.toMap(),
              ),
            );
          }
        }
        if (allocated < quote.totalAmount) {
          blocked.add(
            'Quote #${quote.bestNumber}: allocate the remaining amount '
            'to a milestone.',
          );
        }
      }
    }

    final tasks = await DaoTask().getTasksByJob(jobId, transaction: db);
    if (tasks.isEmpty &&
        approved.isEmpty &&
        job.billingType == BillingType.fixedPrice &&
        job.status == JobStatus.completed) {
      blocked.add('Add agreed work or approve a quote before invoicing.');
    }
    final rate = job.hourlyRate ?? config.hourlyRate;
    for (final task in tasks) {
      versions.add(task.toMap());
      if (task.status == TaskStatus.cancelled &&
          !agreedTasks.contains(task.id)) {
        continue;
      }
      final type = task.effectiveBillingType(job.billingType);
      if (covered.containsKey(task.id)) {
        continue;
      }
      if (type == BillingType.fixedPrice) {
        final agreement = agreements
            .where((a) => a['task_id'] == task.id)
            .firstOrNull;
        if (agreement == null) {
          blocked.add(
            '${task.name}: record an agreed price or approve a quote.',
          );
        } else {
          add(
            BillingCandidate(
              kind: 'task_scope',
              sourceId: agreement['id']! as int,
              taskId: task.id,
              description: 'Agreed work: ${task.name}',
              group: task.name,
              amount: MoneyEx.fromInt(agreement['amount']! as int),
              version: agreement,
            ),
          );
        }
        continue;
      }
      if (type == BillingType.nonBillable) {
        continue;
      }
      final times = await db.query(
        'time_entry',
        where: 'task_id = ?',
        whereArgs: [task.id],
        orderBy: 'id',
      );
      versions.add(times);
      for (final row in times) {
        final time = TimeEntry.fromMap(row);
        if (time.billed || time.endTime == null || time.hours.isZero) {
          continue;
        }
        if (!time.billable && !time.showOnInvoice) {
          continue;
        }
        if (time.billable && !rate.isPositive) {
          blocked.add(
            '${task.name}: set an hourly rate before billing labour.',
          );
          continue;
        }
        final amount = time.billable
            ? time.calcLabourCharge(rate)
            : MoneyEx.zero;
        // Price each source before grouping to keep rounding consistent.
        add(
          BillingCandidate(
            kind: 'time',
            sourceId: time.id,
            taskId: task.id,
            description:
                '${time.billable ? 'Labour' : 'No-charge labour'}: '
                '${time.note ?? task.name}',
            group: task.name,
            amount: amount,
            version: row,
            quantity: time.hours,
            unitPrice: time.billable ? rate : MoneyEx.zero,
            billingDate: LocalDate.fromDateTime(time.startTime),
          ),
        );
      }
      final items = await db.query(
        'task_item',
        where: 'task_id = ?',
        whereArgs: [task.id],
        orderBy: 'id',
      );
      versions.add(items);
      for (final row in items) {
        final item = TaskItem.fromMap(row);
        if (item.billed ||
            !item.completed ||
            item.itemType == TaskItemType.labour) {
          continue;
        }
        final cost = item.calcMaterialCost(BillingType.timeAndMaterial);
        if (cost.lineChargeTotal.isZero) {
          continue;
        }
        final quantity = cost.quantity.copyWith(decimalDigits: 2);
        final representable =
            cost.calculatedUnitCharge.multiplyByFixed(quantity) ==
            cost.lineChargeTotal;
        final calculation = representable
            ? ''
            : ' (${cost.quantity} × ${cost.calculatedUnitCharge})';
        add(
          BillingCandidate(
            kind: 'item',
            sourceId: item.id,
            taskId: task.id,
            description:
                '${item.isReturn
                    ? 'Returned'
                    : item.itemType == TaskItemType.toolsOwn
                    ? 'Tool hire'
                    : 'Material'}: ${item.description}$calculation',
            group: 'Materials for ${task.name}',
            amount: cost.lineChargeTotal,
            version: row,
            quantity: representable ? quantity : Fixed.one,
            unitPrice: representable
                ? cost.calculatedUnitCharge
                : cost.lineChargeTotal,
          ),
        );
      }
    }
    final fee = job.bookingFee ?? config.bookingFee;
    if (!quotedFee &&
        !job.bookingFeeInvoiced &&
        feeLines.isEmpty &&
        fee.isPositive &&
        job.billingType != BillingType.nonBillable) {
      add(
        BillingCandidate(
          kind: 'booking_fee',
          sourceId: jobId,
          description: 'Booking fee',
          group: 'Booking Fee',
          amount: fee,
          version: fee.minorUnits.toInt(),
        ),
      );
    }
    int order(BillingCandidate candidate) => switch (candidate.kind) {
      'booking_fee' => 0,
      'quote' || 'milestone' || 'task_scope' => 1,
      'time' => 2,
      _ => 3,
    };
    candidates.sort((a, b) {
      final group = order(a).compareTo(order(b));
      return group == 0 ? a.key.compareTo(b.key) : group;
    });
    return BillingPreview(
      job: job,
      candidates: List.unmodifiable(candidates),
      blocked: List.unmodifiable(blocked.toSet()),
      contacts: List.unmodifiable(contacts),
      defaultContactId: resolved?.id,
      paymentTerms: config.paymentTerms,
      billingCustomerName: customer?.name ?? 'Select a Bill to customer',
      billingCustomerId: customer?.id,
      taxRate: config.taxRate,
      waivers: List.unmodifiable(waivers),
      bookingFeeQuotes: Map.unmodifiable(bookingFeeQuotes),
      effectiveBookingFee: fee,
      fingerprint: _digest([
        versions,
        candidates.map((c) => c.signature).toList(),
      ]),
    );
  }

  Future<void> waiveCharges({
    required BillingPreview preview,
    required Iterable<String> keys,
    required String reason,
  }) async {
    final selected = keys.toSet();
    if (reason.trim().isEmpty || selected.isEmpty) {
      throw InvoiceException('Select charges and enter a reason.');
    }
    final config = await _BillingConfig.load();
    await _db.transaction((txn) async {
      final current = await _preview(txn, preview.job.id, config);
      if (current.fingerprint != preview.fingerprint) {
        throw InvoiceException(
          'The billable work changed. Refresh and review the charges again.',
        );
      }
      final charges = current.candidates
          .where((charge) => selected.contains(charge.key))
          .toList();
      if (charges.length != selected.length ||
          charges.any((charge) => charge.amount.isNegative)) {
        throw InvoiceException('Select available charges, excluding credits.');
      }
      final now = DateTime.now().toIso8601String();
      for (final charge in charges) {
        await txn.insert('billing_waiver', {
          'job_id': preview.job.id,
          'source_type': charge.kind,
          'source_id': charge.sourceId,
          'source_hash': charge.waiverHash,
          'description': charge.description,
          'amount': charge.amount.minorUnits.toInt(),
          'reason': reason.trim(),
          'waived_date': now,
        });
      }
      await BillingMutation.enqueue(txn, [preview.job.id]);
    });
    Dao.notifier(DaoJob(), preview.job.id);
  }

  Future<void> restoreWaiver({
    required int jobId,
    required int waiverId,
  }) async {
    await _db.transaction((txn) async {
      final changed = await txn.update(
        'billing_waiver',
        {'restored_date': DateTime.now().toIso8601String()},
        where: 'id = ? AND job_id = ? AND restored_date IS NULL',
        whereArgs: [waiverId, jobId],
      );
      if (changed != 0) {
        await BillingMutation.enqueue(txn, [jobId]);
      }
    });
    Dao.notifier(DaoJob(), jobId);
  }

  Future<Invoice> commit(InvoicePlan plan) async {
    final config = await _BillingConfig.load();
    final invoice = await _db.transaction((txn) async {
      final previous = await txn.query(
        'invoice',
        where: 'billing_request_id = ?',
        whereArgs: [plan.id],
      );
      if (previous.isNotEmpty) {
        if (previous.single['billing_plan_hash'] != plan.fingerprint) {
          throw InvoiceException(
            'This request has already created another invoice.',
          );
        }
        return Invoice.fromMap(previous.single);
      }
      final current = await _preview(txn, plan.preview.job.id, config);
      if (current.fingerprint != plan.preview.fingerprint) {
        throw InvoiceException(
          'The billable work changed. Refresh and review the invoice again.',
        );
      }
      final validated = current.select(
        keys: plan.charges.map((c) => c.key),
        contactId: plan.contactId,
        groupByTask: plan.groupByTask,
        allowEarlyBilling: plan.allowEarlyBilling,
        dueDate: plan.dueDate,
      );
      final value = Invoice.forInsert(
        jobId: current.job.id,
        totalAmount: validated.total,
        dueDate: plan.dueDate,
        billingContactId: plan.contactId,
        billingCustomerId: current.billingCustomerId,
        paymentSource: config.externalAccounting
            ? InvoicePaymentSource.xero
            : InvoicePaymentSource.manual,
      );
      final values = value.toMap()
        ..remove('id')
        ..addAll({
          'accounting_state': 'draft',
          'issued_date': null,
          'billing_request_id': plan.id,
          'billing_plan_hash': plan.fingerprint,
        });
      value.id = await txn.insert('invoice', values);
      final groups = <String, int>{};
      for (final charge in validated.charges) {
        final groupName = !plan.groupByTask && charge.kind == 'time'
            ? formatLocalDate(charge.billingDate!)
            : charge.group;
        if (!groups.containsKey(groupName)) {
          final group = InvoiceLineGroup.forInsert(
            invoiceId: value.id,
            name: groupName,
          );
          groups[groupName] = await txn.insert(
            'invoice_line_group',
            group.toMap()..remove('id'),
          );
        }
        final line = InvoiceLine.forInsert(
          invoiceId: value.id,
          invoiceLineGroupId: groups[groupName]!,
          description: charge.description,
          quantity: charge.quantity,
          unitPrice: charge.unitPrice,
          lineTotal: charge.amount,
          taxAmount: config.taxFor(charge.amount),
          taxType: config.taxType,
          taxCodeId: config.taxCodeId,
          fromBookingFee: charge.kind == 'booking_fee',
        );
        line.id = await txn.insert('invoice_line', line.toMap()..remove('id'));
        await txn.insert('billing_allocation', {
          'invoice_id': value.id,
          'invoice_line_id': line.id,
          'source_type': charge.kind,
          'source_id': charge.sourceId,
          'amount': charge.amount.minorUnits.toInt(),
          'created_date': DateTime.now().toIso8601String(),
        });
        if (charge.kind == 'time' || charge.kind == 'item') {
          final table = charge.kind == 'time' ? 'time_entry' : 'task_item';
          final updated = await txn.update(
            table,
            {'billed': 1, 'invoice_line_id': line.id},
            where: 'id = ? AND billed = 0',
            whereArgs: [charge.sourceId],
          );
          if (updated != 1) {
            throw InvoiceException('This work has already been invoiced.');
          }
        } else if (charge.kind == 'milestone') {
          final updated = await txn.update(
            'milestone',
            {'invoice_id': value.id},
            where: 'id = ? AND invoice_id IS NULL AND voided = 0',
            whereArgs: [charge.sourceId],
          );
          if (updated != 1) {
            throw InvoiceException('This milestone has already been invoiced.');
          }
        } else if (charge.kind == 'booking_fee') {
          await txn.update(
            'job',
            {'booking_fee_invoiced': 1},
            where: 'id = ?',
            whereArgs: [current.job.id],
          );
        }
      }
      for (final quoteId
          in validated.charges.map((c) => c.quoteId).whereType<int>().toSet()) {
        await LifecycleEventDispatcher().dispatchQuote(
          quoteId,
          QuoteInvoiced.new,
          context: LifecycleContext(source: 'billing.commit'),
          transaction: txn,
        );
      }
      await BillingMutation.enqueue(txn, {current.job.id});
      return value;
    });
    Dao.notifier(DaoInvoice(), invoice.id);
    Dao.notifier(DaoJob(), invoice.jobId);
    return invoice;
  }
}

class _BillingConfig {
  final Money hourlyRate;
  final Money bookingFee;
  final int paymentTerms;
  final bool externalAccounting;
  final double taxRate;
  final String taxType;
  final int? taxCodeId;
  const _BillingConfig({
    required this.hourlyRate,
    required this.bookingFee,
    required this.paymentTerms,
    required this.externalAccounting,
    required this.taxRate,
    required this.taxType,
    this.taxCodeId,
  });
  List<Object?> get signature => [
    hourlyRate.minorUnits.toInt(),
    bookingFee.minorUnits.toInt(),
    paymentTerms,
    externalAccounting,
    taxRate,
    taxType,
    taxCodeId,
  ];
  Money taxFor(Money gross) => _includedTax(gross, taxRate);

  static Future<_BillingConfig> load({bool pricing = true}) async {
    final system = await DaoSystem().get();
    if (!pricing) {
      return _BillingConfig(
        hourlyRate: system.defaultHourlyRate ?? MoneyEx.dollars(100),
        bookingFee: system.defaultBookingFee ?? MoneyEx.zero,
        paymentTerms: system.paymentTermsInDays,
        externalAccounting: system.isExternalAccountingEnabled(),
        taxRate: 0,
        taxType: 'NONE',
      );
    }
    final mode = await AppSettings.getTaxDisplayMode();
    final rateText = await AppSettings.getTaxRatePercentText();
    final scheme = await DaoTaxScheme().getByCode(
      await AppSettings.getTaxSchemeCode(),
    );
    final code = scheme == null
        ? null
        : await DaoTaxCode().getDefaultSalesCode(scheme.id);
    final rate = mode == TaxDisplayMode.none
        ? 0.0
        : double.tryParse(rateText) ?? (code?.rateBasisPoints ?? 0) / 100;
    if (!rate.isFinite || rate < 0) {
      throw InvoiceException('Configure a non-negative tax rate.');
    }
    return _BillingConfig(
      hourlyRate: system.defaultHourlyRate ?? MoneyEx.dollars(100),
      bookingFee: system.defaultBookingFee ?? MoneyEx.zero,
      paymentTerms: system.paymentTermsInDays,
      externalAccounting: system.isExternalAccountingEnabled(),
      taxRate: rate,
      taxType: rate == 0 ? 'NONE' : code?.externalTaxCode ?? 'OUTPUT',
      taxCodeId: code?.rateBasisPoints == (rate * 100).round()
          ? code?.id
          : null,
    );
  }
}
