/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.
*/

import 'entity.dart';

enum MailingStatus {
  draft('Draft'),
  routeReady('Route Ready'),
  inProgress('In Progress'),
  completed('Completed');

  const MailingStatus(this.display);
  final String display;

  static MailingStatus fromName(String? name) => MailingStatus.values
      .firstWhere((value) => value.name == name, orElse: () => draft);
}

class Mailing extends Entity<Mailing> {
  final String name;
  final String? notes;
  final MailingStatus status;
  final String labelLayoutId;
  final String? routeOrigin;
  final bool routeOptimised;

  Mailing._({
    required super.id,
    required this.name,
    required this.notes,
    required this.status,
    required this.labelLayoutId,
    required this.routeOrigin,
    required this.routeOptimised,
    required super.createdDate,
    required super.modifiedDate,
  });

  Mailing.forInsert({
    required this.name,
    required this.labelLayoutId,
    this.notes,
    this.status = MailingStatus.draft,
    this.routeOrigin,
    this.routeOptimised = false,
  }) : super.forInsert();

  Mailing copyWith({
    String? name,
    String? notes,
    MailingStatus? status,
    String? labelLayoutId,
    String? routeOrigin,
    bool? routeOptimised,
  }) => Mailing._(
    id: id,
    name: name ?? this.name,
    notes: notes ?? this.notes,
    status: status ?? this.status,
    labelLayoutId: labelLayoutId ?? this.labelLayoutId,
    routeOrigin: routeOrigin ?? this.routeOrigin,
    routeOptimised: routeOptimised ?? this.routeOptimised,
    createdDate: createdDate,
    modifiedDate: DateTime.now(),
  );

  factory Mailing.fromMap(Map<String, dynamic> map) => Mailing._(
    id: map['id'] as int,
    name: map['name'] as String,
    notes: map['notes'] as String?,
    status: MailingStatus.fromName(map['status'] as String?),
    labelLayoutId: map['label_layout_id'] as String,
    routeOrigin: map['route_origin'] as String?,
    routeOptimised: (map['route_optimised'] as int? ?? 0) == 1,
    createdDate: DateTime.parse(map['createdDate'] as String),
    modifiedDate: DateTime.parse(map['modifiedDate'] as String),
  );

  @override
  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'notes': notes,
    'status': status.name,
    'label_layout_id': labelLayoutId,
    'route_origin': routeOrigin,
    'route_optimised': routeOptimised ? 1 : 0,
    'createdDate': createdDate.toIso8601String(),
    'modifiedDate': modifiedDate.toIso8601String(),
  };
}
