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

import 'entity.dart';

enum AccountingSyncOperation {
  create(0),
  update(1),
  delete(2),
  voidRemote(3);

  final int ordinal;
  const AccountingSyncOperation(this.ordinal);

  static AccountingSyncOperation fromOrdinal(int? value) =>
      AccountingSyncOperation.values.firstWhere(
        (operation) => operation.ordinal == value,
        orElse: () => AccountingSyncOperation.create,
      );
}

enum AccountingSyncEventStatus {
  pending(0),
  synced(1),
  conflict(2),
  failed(3),
  superseded(4);

  final int ordinal;
  const AccountingSyncEventStatus(this.ordinal);

  static AccountingSyncEventStatus fromOrdinal(int? value) =>
      AccountingSyncEventStatus.values.firstWhere(
        (status) => status.ordinal == value,
        orElse: () => AccountingSyncEventStatus.pending,
      );
}

class AccountingSyncEvent extends Entity<AccountingSyncEvent> {
  String provider;
  String entityType;
  int? localId;
  String? externalId;
  AccountingSyncOperation operation;
  AccountingSyncEventStatus status;
  DateTime? lastAttemptAt;
  int attemptCount;
  String? lastError;
  String? contentHash;
  String? payload;

  AccountingSyncEvent({
    required super.id,
    required this.provider,
    required this.entityType,
    required this.localId,
    required this.externalId,
    required this.operation,
    required this.status,
    required this.attemptCount,
    required super.createdDate,
    required super.modifiedDate,
    this.lastAttemptAt,
    this.lastError,
    this.contentHash,
    this.payload,
  }) : super();

  AccountingSyncEvent.forInsert({
    required this.provider,
    required this.entityType,
    required this.operation,
    this.localId,
    this.externalId,
    this.status = AccountingSyncEventStatus.pending,
    this.lastAttemptAt,
    this.attemptCount = 0,
    this.lastError,
    this.contentHash,
    this.payload,
  }) : super.forInsert();

  AccountingSyncEvent copyWith({
    String? provider,
    String? entityType,
    int? localId,
    String? externalId,
    AccountingSyncOperation? operation,
    AccountingSyncEventStatus? status,
    DateTime? lastAttemptAt,
    int? attemptCount,
    String? lastError,
    String? contentHash,
    String? payload,
  }) => AccountingSyncEvent(
    id: id,
    provider: provider ?? this.provider,
    entityType: entityType ?? this.entityType,
    localId: localId ?? this.localId,
    externalId: externalId ?? this.externalId,
    operation: operation ?? this.operation,
    status: status ?? this.status,
    lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
    attemptCount: attemptCount ?? this.attemptCount,
    lastError: lastError ?? this.lastError,
    contentHash: contentHash ?? this.contentHash,
    payload: payload ?? this.payload,
    createdDate: createdDate,
    modifiedDate: DateTime.now(),
  );

  factory AccountingSyncEvent.fromMap(Map<String, dynamic> map) =>
      AccountingSyncEvent(
        id: map['id'] as int,
        provider: map['provider'] as String,
        entityType: map['entity_type'] as String,
        localId: map['local_id'] as int?,
        externalId: map['external_id'] as String?,
        operation: AccountingSyncOperation.fromOrdinal(
          map['operation'] as int?,
        ),
        status: AccountingSyncEventStatus.fromOrdinal(map['status'] as int?),
        lastAttemptAt: map['last_attempt_at'] == null
            ? null
            : DateTime.parse(map['last_attempt_at'] as String),
        attemptCount: map['attempt_count'] as int? ?? 0,
        lastError: map['last_error'] as String?,
        contentHash: map['content_hash'] as String?,
        payload: map['payload'] as String?,
        createdDate: DateTime.parse(map['created_date'] as String),
        modifiedDate: DateTime.parse(map['modified_date'] as String),
      );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'provider': provider,
    'entity_type': entityType,
    'local_id': localId,
    'external_id': externalId,
    'operation': operation.ordinal,
    'status': status.ordinal,
    'last_attempt_at': lastAttemptAt?.toIso8601String(),
    'attempt_count': attemptCount,
    'last_error': lastError,
    'content_hash': contentHash,
    'payload': payload,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };
}
