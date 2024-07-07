import 'entity.dart';

enum TaskStatusEnum {
  toBeSCheduled,
  awaitingMaterials,
  completed,
  onHold,
  inProgress,
  cancelled,
  preApproved,
  approved,
}

/// These MUST match the db [TaskStatus] name columns.
extension TaskStatusEnumExtension on TaskStatusEnum {
  String get colValue {
    switch (this) {
      case TaskStatusEnum.toBeSCheduled:
        return 'To be scheduled';
      case TaskStatusEnum.awaitingMaterials:
        return 'Awaiting Materials';
      case TaskStatusEnum.completed:
        return 'Completed';
      case TaskStatusEnum.onHold:
        return 'On Hold';
      case TaskStatusEnum.inProgress:
        return 'In progress';
      case TaskStatusEnum.cancelled:
        return 'Cancelled';
      case TaskStatusEnum.preApproved:
        return 'Pre-approved';
      case TaskStatusEnum.approved:
        return 'Approved';
    }
  }
}

class TaskStatus extends Entity<TaskStatus> {
  TaskStatus({
    required super.id,
    required this.name,
    required this.description,
    required this.colorCode,
    required super.createdDate,
    required super.modifiedDate,
  }) : super();

  TaskStatus.forInsert({
    required this.name,
    required this.description,
    required this.colorCode,
  }) : super.forInsert();

  TaskStatus.forUpdate({
    required super.entity,
    required this.name,
    required this.description,
    required this.colorCode,
  }) : super.forUpdate();

  factory TaskStatus.fromMap(Map<String, dynamic> map) => TaskStatus(
        id: map['id'] as int,
        name: map['name'] as String,
        description: map['description'] as String,
        colorCode: map['color_code'] as String,
        createdDate: DateTime.parse(map['createdDate'] as String),
        modifiedDate: DateTime.parse(map['modifiedDate'] as String),
      );

  String name;
  String description;
  String colorCode;

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'color_code': colorCode,
        'createdDate': createdDate.toIso8601String(),
        'modifiedDate': modifiedDate.toIso8601String(),
      };

  bool isComplete() {
    switch (name) {
      case 'To be scheduled':
        return false;
      case 'Awaiting Materials':
        return false;
      case 'Completed':
        return true;
      case 'On Hold':
        return false;
      case 'In progress':
        return false;
      case 'Cancelled':
        return true;
      case 'Pre-approved':
        return false;
      case 'Approved':
        return false;
      default:
        return false;
    }
  }

  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is TaskStatus &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.colorCode == colorCode &&
        other.createdDate == createdDate &&
        other.modifiedDate == modifiedDate;
  }

  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      description.hashCode ^
      colorCode.hashCode ^
      createdDate.hashCode ^
      modifiedDate.hashCode;

  @override
  String toString() => 'name: $name, description: $description';
}
