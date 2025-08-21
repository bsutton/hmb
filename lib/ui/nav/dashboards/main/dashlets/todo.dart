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

/// Dashlet for active jobs count
library;

import 'package:flutter/material.dart';

import '../../../../../dao/dao_todo.dart';
import '../../../../../entity/todo.dart';
import '../../dashlet_card.dart';

class ToDoDashlet extends StatelessWidget {
  const ToDoDashlet({super.key});

  @override
  Widget build(BuildContext context) => DashletCard<int>.route(
    label: 'Todo',
    hint: 'Create actionable items',
    icon: Icons.work,
    value: () async {
      final todos = await DaoToDo().getFiltered(status: ToDoStatus.open);
      return DashletValue(todos.length);
    },
    route: '/home/todo',
  );
}
