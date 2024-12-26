import 'entity.dart';

class Task extends Entity<Task> {
  Task({
    required super.id,
    required this.jobId,
    required this.name,
    required this.description,
    required this.taskStatusId,
    required super.createdDate,
    required super.modifiedDate,
    // this.billingType =
    //     BillingType.timeAndMaterial // New field for BillingType
  }) : super();

  factory Task.fromMap(Map<String, dynamic> map) => Task(
        id: map['id'] as int,
        jobId: map['job_id'] as int,
        name: map['name'] as String,
        description: map['description'] as String,
        taskStatusId: map['task_status_id'] as int,
        createdDate: DateTime.parse(map['createdDate'] as String),
        modifiedDate: DateTime.parse(map['modifiedDate'] as String),
        // billingType: BillingType.values.firstWhere(
        //     (e) => e.name == map['billing_type'],
        //     orElse: () =>
        //         BillingType.timeAndMaterial), // New field for BillingType
      );

  Task.forInsert({
    required this.jobId,
    required this.name,
    required this.description,
    required this.taskStatusId,
    // this.billingType =
    //     BillingType.timeAndMaterial // New field for BillingType
  }) : super.forInsert();

  Task.forUpdate({
    required super.entity,
    required this.jobId,
    required this.name,
    required this.description,
    required this.taskStatusId,
    // this.billingType =
    //     BillingType.timeAndMaterial // New field for BillingType
  }) : super.forUpdate();

  int jobId;
  String name;
  String description;
  int taskStatusId;

  // If [billingType] is null then take it from the Job.
  // BillingType? billingType;

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'job_id': jobId,
        'name': name,
        'description': description,
        'task_status_id': taskStatusId,
        // 'billing_type': billingType?.name, // New field for BillingType
        'createdDate': createdDate.toIso8601String(),
        'modifiedDate': modifiedDate.toIso8601String(),
      };

  @override
  String toString() =>
      'Task(id: $id, jobId: $jobId, name: $name, statusID: $taskStatusId)';
}
