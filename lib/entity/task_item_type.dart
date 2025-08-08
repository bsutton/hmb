/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:strings/strings.dart';

/// Must match the db entries.
enum TaskItemType {
  materialsBuy(
    1,
    label: 'Materials - buy',
    description: 'Materials need to be purchased',
    color: '#FFFFE0',
    toPurchase: true,
  ),
  materialsStock(
    2,
    label: 'Materials - stock',
    description: 'Materials to be taken from stock',
    color: '#D3D3D3',
    toPurchase: false,
  ),
  toolsBuy(
    3,
    label: 'Tools - buy',
    description: 'Tool that needs to be purchased',
    color: '#90EE90',
    toPurchase: true,
  ),
  toolsOwn(
    4,
    label: 'Tools - own',
    description: 'Tool that we own',
    color: '#FAFAD2',
    toPurchase: false,
  ),
  labour(
    5,
    label: 'Labour',
    description: 'Work to be done',
    color: '#87CEFA',
    toPurchase: false,
  ),
  consumablesStock(
    6,
    label: 'Consumables - stock',
    description: 'Drills, Sand Paper etc held in stock',
    color: '#87CEFA',
    toPurchase: true,
  ),
  consumablesBuy(
    7,
    label: 'Consumables - buy',
    description: 'Drills, Sand Paper etc to be purchased',
    color: '#87CEFA',
    toPurchase: true,
  );

  const TaskItemType(
    this.id, {
    required this.label,
    required this.description,
    required this.color,
    required this.toPurchase,
  });

  final int id;
  final String label;
  final String description;
  final String color;
  final bool toPurchase;

  static TaskItemType fromId(int id) => values[id - 1];

  static List<TaskItemType> getByFilter(String? filter) =>
      Strings.isBlank(filter)
      ? TaskItemType.values
      : TaskItemType.values
            .where(
              (type) =>
                  type.label.toLowerCase().contains(filter!.toLowerCase()) ||
                  type.description.toLowerCase().contains(filter.toLowerCase()),
            )
            .toList();
}
