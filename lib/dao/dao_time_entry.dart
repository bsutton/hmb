import 'package:fixed/fixed.dart';
import 'package:june/june.dart';
import 'package:sqflite/sqflite.dart';

import '../entity/entity.g.dart';
import '../util/date_time_ex.dart';
import '../util/local_date.dart';
import 'dao.dart';

class DaoTimeEntry extends Dao<TimeEntry> {
  @override
  TimeEntry fromMap(Map<String, dynamic> map) => TimeEntry.fromMap(map);

  @override
  String get tableName => 'time_entry';

  Future<List<TimeEntry>> getByTask(int? taskId) async {
    final db = withoutTransaction();
    if (taskId == null) {
      return [];
    }
    final results = await db.query(tableName,
        where: 'task_id = ?', whereArgs: [taskId], orderBy: 'start_time desc');
    return results.map(TimeEntry.fromMap).toList();
  }

  /// Find the active [TimeEntry] there should only ever
  /// be one or none.
  Future<TimeEntry?> getActiveEntry() async {
    final db = withoutTransaction();

    final results = await db.query(tableName,
        where: 'end_time is null', orderBy: 'start_time desc');
    final list = results.map(TimeEntry.fromMap);
    assert(list.length <= 1, 'There should only ever by one active entry');
    return list.firstOrNull;
  }

  @override
  JuneStateCreator get juneRefresher => DbTimeEntryChanged.new;

  Future<void> markAsNotbilled(int invoiceLineId) async {
    final db = withoutTransaction();
    await db.update(
      tableName,
      {'invoice_line_id': null, 'billed': 0},
      where: 'invoice_line_id = ?',
      whereArgs: [invoiceLineId],
    );
  }

  Future<void> markAsBilled(TimeEntry entity, int invoiceLineId) async {
    final db = withoutTransaction();
    await db.update(
      tableName,
      {'invoice_line_id': invoiceLineId, 'billed': 1},
      where: 'id = ?',
      whereArgs: [entity.id],
    );
  }

  Future<List<TimeEntry>> getByInvoiceLineId(int invoiceLineId) async {
    final db = withoutTransaction();
    final results = await db.query(tableName,
        where: 'invoice_line_id = ?', whereArgs: [invoiceLineId]);
    return results.map(TimeEntry.fromMap).toList();
  }

  Future<void> deleteByTask(int id, [Transaction? transaction]) async {
    final db = withinTransaction(transaction);
    await db.delete(
      tableName,
      where: 'task_id =?',
      whereArgs: [id],
    );
  }

  /// Get the set of [TimeEntry]s for the given job.
  /// Returns the most recent first.
  Future<List<TimeEntry>> getByJob(int? jobId) async {
    final db = withoutTransaction();
    if (jobId == null) {
      return [];
    }
    final results = await db.rawQuery('''
      select * from $tableName
      where task_id in (select id from task where job_id =?)
      order by end_time desc
''', [jobId]);
    return results.map(TimeEntry.fromMap).toList();
  }

  /// Get the non-billed labour for the given [task] in the given [date]
  Future<LabourForTaskOnDate> getLabourForDate(
      Task task, LocalDate date) async {
    final timeEntries = await getByTask(task.id);

    final matched = <TimeEntry>[];
    for (final timeEntry in timeEntries) {
      if (timeEntry.billed) {
        continue;
      }

      if (timeEntry.startTime.toLocalDate() == date) {
        matched.add(timeEntry);
      }
    }

    return LabourForTaskOnDate(task, date, matched);
  }

  // Future<List<LabourForTaskOnDate>> collectLabourPerDay(
  //     Job job, Task task, int invoiceId) async {
  //   final timeEntries = await DaoTimeEntry().getByTask(task.id);

  //   // Create a map to group time entries by date
  //   final timeEntryGroups = <LocalDate, List<TimeEntry>>{};

  //   for (final timeEntry in timeEntries.where((entry) => !entry.billed)) {
  //     final date = LocalDate.fromDateTime(timeEntry.startTime);
  //     timeEntryGroups.putIfAbsent(date, () => []).add(timeEntry);
  //   }

  //   final days = <LabourForTaskOnDate>[];

  //   /// Sum the hours
  //   for (final entry in timeEntryGroups.entries) {
  //     final date = entry.key;
  //     days.add(LabourForTaskOnDate(date, entry.value));
  //   }

  //   return days;
  // }
}

/// Can be used to notify the UI that the time entry has changed.
/// This method is called each time the database is updated through the [Dao]
/// methods - delete, insert and update.
/// You can also for a notification by calling:
/// ```
/// DbTimeEntryChanged.notify();
/// ```
class DbTimeEntryChanged extends JuneState {
  DbTimeEntryChanged();
}

/// Used to accumulate all time entries, for a specific task and date
/// that haven't yet been billed.
class LabourForTaskOnDate {
  LabourForTaskOnDate(this.task, this.date, this.timeEntries) {
    hours =
        timeEntries.fold(Duration.zero, (sum, value) => sum + value.duration);
  }
  Task task;
  LocalDate date;
  List<TimeEntry> timeEntries;
  late Duration hours;

  Fixed get durationInHours => Fixed.fromNum(hours.inMinutes / 60, scale: 2);
}
