import 'package:money2/money2.dart';

import 'entity.dart';
import 'job.dart';

class Task extends Entity<Task> {
  Task(
      {required super.id,
      required this.jobId,
      required this.name,
      required this.description,
      required this.effortInHours,
      required this.estimatedCost,
      required this.taskStatusId,
      required super.createdDate,
      required super.modifiedDate,
      this.billingType =
          BillingType.timeAndMaterial // New field for BillingType
      })
      : super();

  factory Task.fromMap(Map<String, dynamic> map) => Task(
        id: map['id'] as int,
        jobId: map['job_d'] as int,
        name: map['name'] as String,
        description: map['description'] as String,
        effortInHours: Fixed.fromInt(map['effort_in_hours'] as int),
        estimatedCost:
            Money.fromInt(map['estimated_cost'] as int, isoCode: 'AUD'),
        taskStatusId: map['task_status_id'] as int,
        createdDate: DateTime.parse(map['createdDate'] as String),
        modifiedDate: DateTime.parse(map['modifiedDate'] as String),
        billingType: BillingType.values.firstWhere(
            (e) => e.name == map['billing_type'],
            orElse: () =>
                BillingType.timeAndMaterial), // New field for BillingType
      );

  Task.forInsert(
      {required this.jobId,
      required this.name,
      required this.description,
      required this.effortInHours,
      required this.estimatedCost,
      required this.taskStatusId,
      this.billingType =
          BillingType.timeAndMaterial // New field for BillingType
      })
      : super.forInsert();

  Task.forUpdate(
      {required super.entity,
      required this.jobId,
      required this.name,
      required this.description,
      required this.effortInHours,
      required this.estimatedCost,
      required this.taskStatusId,
      this.billingType =
          BillingType.timeAndMaterial // New field for BillingType
      })
      : super.forUpdate();

  int jobId;
  String name;
  String description;
  Fixed? effortInHours;
  Money? estimatedCost;
  int taskStatusId;
  BillingType billingType; // New field for BillingType

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'job_id': jobId,
        'name': name,
        'description': description,
        'effort_in_hours': Fixed.copyWith(effortInHours ?? Fixed.zero, scale: 2)
            .minorUnits
            .toInt(),
        'estimated_cost':
            estimatedCost?.copyWith(decimalDigits: 2).minorUnits.toInt(),
        'task_status_id': taskStatusId,
        'billing_type': billingType.name, // New field for BillingType
        'createdDate': createdDate.toIso8601String(),
        'modifiedDate': modifiedDate.toIso8601String(),
      };

  @override
  String toString() =>
      'Task(id: $id, jobId: $jobId, name: $name, statusID: $taskStatusId)';
}
