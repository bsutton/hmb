import 'entity.dart';

class QuoteLineGroup extends Entity<QuoteLineGroup> {
  QuoteLineGroup({
    required super.id,
    required this.quoteId,
    required this.name,
    required this.assumption,
    required super.createdDate,
    required super.modifiedDate,
  }) : super();

  QuoteLineGroup.forInsert({
    required this.quoteId,
    required this.name,
    required this.assumption,
  }) : super.forInsert();

  QuoteLineGroup.forUpdate({
    required super.entity,
    required this.quoteId,
    required this.name,
    required this.assumption,
  }) : super.forUpdate();

  factory QuoteLineGroup.fromMap(Map<String, dynamic> map) => QuoteLineGroup(
    id: map['id'] as int,
    quoteId: map['quote_id'] as int,
    name: map['name'] as String,
    assumption: map['assumption'] as String,
    createdDate: DateTime.parse(map['created_date'] as String),
    modifiedDate: DateTime.parse(map['modified_date'] as String),
  );

  int quoteId;
  String name;
  String assumption;

  QuoteLineGroup copyWith({
    int? id,
    int? quoteId,
    String? name,
    String? assumption,
    DateTime? createdDate,
    DateTime? modifiedDate,
  }) => QuoteLineGroup(
    id: id ?? this.id,
    quoteId: quoteId ?? this.quoteId,
    name: name ?? this.name,
    assumption: assumption ?? this.assumption,
    createdDate: createdDate ?? this.createdDate,
    modifiedDate: modifiedDate ?? this.modifiedDate,
  );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'quote_id': quoteId,
    'name': name,
    'assumption': assumption,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };
}
