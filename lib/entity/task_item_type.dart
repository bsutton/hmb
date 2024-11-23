import 'entity.dart';

/// Must match the db entries.
enum TaskItemTypeEnum {
  materialsBuy(1, 'Materials - buy'),
  materialsStock(2, 'Materials - stock'),
  toolsBuy(3, 'Tools - buy'),
  toolsOwn(4, 'Tools - own'),
  labour(5, 'Labour');

  const TaskItemTypeEnum(this.id, this.description);

  final int id;
  final String description;

  static TaskItemTypeEnum fromId(int id) => values[id - 1];
}

class TaskItemType extends Entity<TaskItemType> {
  TaskItemType({
    required super.id,
    required this.name,
    required this.description,
    required this.toPurchase,
    required this.colorCode,
    required super.createdDate,
    required super.modifiedDate,
  }) : super();

  TaskItemType.forInsert({
    required this.name,
    required this.description,
    required this.toPurchase,
    required this.colorCode,
  }) : super.forInsert();

  TaskItemType.forUpdate({
    required super.entity,
    required this.name,
    required this.description,
    required this.toPurchase,
    required this.colorCode,
  }) : super.forUpdate();

  factory TaskItemType.fromMap(Map<String, dynamic> map) => TaskItemType(
        id: map['id'] as int,
        name: map['name'] as String,
        description: map['description'] as String,
        toPurchase: map['to_purchase'] as int == 1,
        colorCode: map['color_code'] as String,
        createdDate: DateTime.parse(map['created_date'] as String),
        modifiedDate: DateTime.parse(map['modified_date'] as String),
      );

  String name;
  String description;
  bool toPurchase;
  String colorCode;

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'to_purchase': toPurchase ? 1 : 0,
        'color_code': colorCode,
        'created_date': createdDate.toIso8601String(),
        'modified_date': modifiedDate.toIso8601String(),
      };
}
