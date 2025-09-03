/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:strings/strings.dart';

import 'task.dart';

/// Used by [Task] to indicate the status.
/// DO NOT CHANGE THE [id]s as they are used in the db
/// to refer to a specific status.
enum TaskStatus {
  awaitingApproval(
    id: 1,
    name: 'Awaiting Approval',
    description: 'The task is yet to be approved by the customer.',
    colorCode: '#FFDAB9',
    ordinal: 1,
    canBeTimed: false,
  ),
  approved(
    id: 2,
    name: 'Approved',
    description: 'The task has been approved by the customer.',
    colorCode: '#3CB371',
    ordinal: 2,
    canBeTimed: true,
  ),
  inProgress(
    id: 3,
    name: 'In Progress',
    description: 'The task is currently in progress',
    colorCode: '#87CEFA',
    ordinal: 3,
    canBeTimed: true,
  ),
  awaitingMaterials(
    id: 4,
    name: 'Awaiting Materials',
    description: 'The task is paused until materials are available',
    colorCode: '#D3D3D3',
    ordinal: 4,
    canBeTimed: true,
  ),
  onHold(
    id: 5,
    name: 'On Hold',
    description: 'The task is on hold',
    colorCode: '#FAFAD2',
    ordinal: 5,
    canBeTimed: true,
  ),
  completed(
    id: 6,
    name: 'Completed',
    description: 'The task is completed',
    colorCode: '#90EE90',
    ordinal: 6,
    canBeTimed: false,
  ),
  cancelled(
    id: 7,
    name: 'Cancelled',
    description: 'The Task has been cancelled by the customer',
    colorCode: '#57CEFA',
    ordinal: 7,
    canBeTimed: false,
  );

  const TaskStatus({
    required this.id,
    required this.name,
    required this.description,
    required this.colorCode,
    required this.ordinal,
    required this.canBeTimed,
  });

  /// Primary key id in the database.
  final int id;

  /// Display name matching the `name` column.
  final String name;

  /// Description from the `description` column.
  final String description;

  /// Hex color code from the `color_code` column.
  final String colorCode;

  /// Ordinal ordering (may be null).
  final int ordinal;

  final bool canBeTimed;

  /// Lookup by database id.
  static TaskStatus fromId(int id) => TaskStatus.values.firstWhere(
    (e) => e.id == id,
    orElse: () => throw ArgumentError('Invalid TaskStatus id: $id'),
  );

  /// Column value for `name` in the database.
  String get colValue => name;

  bool isWithdrawn() => this == cancelled || this == onHold;

  bool isComplete() => this == completed;

  bool toBeEstimated() => this == awaitingApproval;

  bool isActive() =>
      this == approved || this == inProgress || this == awaitingMaterials;

  bool isInActive() => this == onHold || this == completed || this == cancelled;

  @override
  String toString() => 'name: $name, description: $description';

  static List<TaskStatus> getByFilter(String? filter) {
    final all = [...values]..sort((lhs, rhs) => lhs.ordinal - rhs.ordinal);
    if (Strings.isBlank(filter)) {
      return all;
    }
    return all
        .where(
          (status) =>
              status.name.contains(filter!) ||
              status.description.contains(filter),
        )
        .toList();
  }
}
