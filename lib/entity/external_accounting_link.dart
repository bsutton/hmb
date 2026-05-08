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

enum ExternalAccountingSyncStatus {
  none(0),
  linked(1),
  deleted(2),
  voided(3),
  error(4);

  final int ordinal;
  const ExternalAccountingSyncStatus(this.ordinal);

  static ExternalAccountingSyncStatus fromOrdinal(int? value) =>
      ExternalAccountingSyncStatus.values.firstWhere(
        (status) => status.ordinal == value,
        orElse: () => ExternalAccountingSyncStatus.none,
      );
}

class ExternalAccountingLink extends Entity<ExternalAccountingLink> {
  String provider;
  String entityType;
  int localId;
  String? externalId;
  String? externalNumber;
  ExternalAccountingSyncStatus syncStatus;
  DateTime? lastSyncedAt;
  DateTime? remoteUpdatedAt;
  String? lastError;
  String? contentHash;

  ExternalAccountingLink({
    required super.id,
    required this.provider,
    required this.entityType,
    required this.localId,
    required super.createdDate,
    required super.modifiedDate,
    this.externalId,
    this.externalNumber,
    this.syncStatus = ExternalAccountingSyncStatus.none,
    this.lastSyncedAt,
    this.remoteUpdatedAt,
    this.lastError,
    this.contentHash,
  }) : super();

  ExternalAccountingLink.forInsert({
    required this.provider,
    required this.entityType,
    required this.localId,
    this.externalId,
    this.externalNumber,
    this.syncStatus = ExternalAccountingSyncStatus.none,
    this.lastSyncedAt,
    this.remoteUpdatedAt,
    this.lastError,
    this.contentHash,
  }) : super.forInsert();

  factory ExternalAccountingLink.fromMap(Map<String, dynamic> map) =>
      ExternalAccountingLink(
        id: map['id'] as int,
        provider: map['provider'] as String,
        entityType: map['entity_type'] as String,
        localId: map['local_id'] as int,
        externalId: map['external_id'] as String?,
        externalNumber: map['external_number'] as String?,
        syncStatus: ExternalAccountingSyncStatus.fromOrdinal(
          map['sync_status'] as int?,
        ),
        lastSyncedAt: map['last_synced_at'] == null
            ? null
            : DateTime.parse(map['last_synced_at'] as String),
        remoteUpdatedAt: map['remote_updated_at'] == null
            ? null
            : DateTime.parse(map['remote_updated_at'] as String),
        lastError: map['last_error'] as String?,
        contentHash: map['content_hash'] as String?,
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
    'external_number': externalNumber,
    'sync_status': syncStatus.ordinal,
    'last_synced_at': lastSyncedAt?.toIso8601String(),
    'remote_updated_at': remoteUpdatedAt?.toIso8601String(),
    'last_error': lastError,
    'content_hash': contentHash,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };
}
