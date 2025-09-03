/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton.
 All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

// lib/src/entity/time_entry.dart
import 'package:money2/money2.dart';

import 'entity.dart';
import 'entity.g.dart' show Supplier, Task;

/// A record of time spent on a [Task], optionally linked to an invoice line
/// and/or a [Supplier].
class TimeEntry extends Entity<TimeEntry> {
  /// entries over this interval are considered suspicious,
  /// so we warn the user in case they entered the end time incorrectly.
  static const longDurationHours = 12;

  int taskId;
  DateTime startTime;
  DateTime? endTime;
  String? note;
  bool billed;

  /// If the time entry has been invoiced then this is the invoice line
  /// that it was billed to.
  int? invoiceLineId;

  /// Optional supplier associated with this time entry.
  int? supplierId;

  TimeEntry({
    required super.id,
    required this.taskId,
    required this.startTime,
    required super.createdDate,
    required super.modifiedDate,
    this.endTime,
    this.note,
    this.billed = false,
    this.invoiceLineId,
    this.supplierId,
  }) : super();

  factory TimeEntry.fromMap(Map<String, dynamic> map) => TimeEntry(
    id: map['id'] as int,
    taskId: map['task_id'] as int,
    startTime: DateTime.parse(map['start_time'] as String),
    endTime: map['end_time'] != null
        ? DateTime.parse(map['end_time'] as String)
        : null,
    note: map['notes'] as String?,
    billed: map['billed'] == 1,
    invoiceLineId: map['invoice_line_id'] as int?,
    supplierId: map['supplier_id'] as int?,
    createdDate: DateTime.parse(map['created_date'] as String),
    modifiedDate: DateTime.parse(map['modified_date'] as String),
  );

  /// Create a new entry for insertion (ID, created/modified dates set by DB)
  TimeEntry.forInsert({
    required this.taskId,
    required this.startTime,
    this.endTime,
    this.note,
    this.billed = false,
    this.supplierId,
  }) : super.forInsert();

  TimeEntry copyWith({
    int? taskId,
    DateTime? startTime,
    DateTime? endTime,
    String? note,
    bool? billed,
    int? invoiceLineId,
    int? supplierId,
  }) => TimeEntry(
    id: id,
    taskId: taskId ?? this.taskId,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    note: note ?? this.note,
    billed: billed ?? this.billed,
    invoiceLineId: invoiceLineId ?? this.invoiceLineId,
    supplierId: supplierId ?? this.supplierId,
    createdDate: createdDate,
    modifiedDate: DateTime.now(),
  );

  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  Fixed get hours => Fixed.fromNum(duration.inMinutes / 60);

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'task_id': taskId,
    'start_time': startTime.toIso8601String(),
    'end_time': endTime?.toIso8601String(),
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
    'notes': note,
    'billed': billed ? 1 : 0,
    'invoice_line_id': invoiceLineId,
    'supplier_id': supplierId,
  };

  /// Did this current entry's endTime fall in the last quarter hour?
  /// An entry that is still running or was stopped in the future
  /// is considered to be in the last quarter hour.
  /// We do allow entries to be stopped in the future but only
  /// within the next fifteen minutes - as we bill in fifteen minutes
  /// blocks or part thereof.
  bool recentlyStopped(DateTime now) =>
      endTime == null || now.difference(endTime!).inMinutes.abs() <= 15;

  /// Calculate the labour charge based on an [hourlyRate].
  Money calcLabourCharge(Money hourlyRate) {
    final minutes = duration.inMinutes / 60;
    return hourlyRate.multiplyByFixed(Fixed.fromNum(minutes));
  }

  Fixed calcHours() => Fixed.fromNum(duration.inMinutes / 60);
}
