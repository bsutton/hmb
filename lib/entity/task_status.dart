/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:strings/strings.dart';

import 'task.dart';

/// Used by [Task] to indicate the status.
/// DO NOT CHANGE THE [id]s as they are used in the db
/// to refer to a specific status.
enum TaskStatus {
  toBeScheduled(
    1,
    'To be scheduled',
    'The customer has agreed to proceed but we have not set a start date',
    '#FFFFE0',
    1,
  ),
  preApproval(
    7,
    'Pre-approval',
    'The task is yet to be approved by the customer.',
    '#FFDAB9',
    2,
  ),
  approved(
    8,
    'Approved',
    'The task has been approved by the customer.',
    '#3CB371',
    3,
  ),
  inProgress(
    5,
    'In Progress',
    'The task is currently in progress',
    '#87CEFA',
    4,
  ),
  awaitingMaterials(
    2,
    'Awaiting Materials',
    'The task is paused until materials are available',
    '#D3D3D3',
    5,
  ),
  onHold(4, 'On Hold', 'The task is on hold', '#FAFAD2', 6),
  completed(3, 'Completed', 'The task is completed', '#90EE90', 7),
  cancelled(
    6,
    'Cancelled',
    'The Task has been cancelled by the customer',
    '#57CEFA',
    8,
  );

  const TaskStatus(
    this.id,
    this.name,
    this.description,
    this.colorCode,
    this.ordinal,
  );

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

  /// Lookup by database id.
  static TaskStatus fromId(int id) => TaskStatus.values.firstWhere(
    (e) => e.id == id,
    orElse: () => throw ArgumentError(r'Invalid TaskStatus id: $id'),
  );

  /// Column value for `name` in the database.
  String get colValue => name;

  bool isCancelled() => name == 'Cancelled';

  bool isComplete() =>
      this == toBeScheduled || this == completed || this == cancelled;

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
