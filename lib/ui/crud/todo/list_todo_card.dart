import 'package:flutter/material.dart';
import 'package:strings/strings.dart';

import '../../../dao/dao_todo.dart';
import '../../../entity/todo.dart';
import '../../../util/format.dart';
import '../../dialog/hmb_snooze_picker.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/select/hmb_entity_chip.dart';
import '../../widgets/text/text.g.dart';
import '../../widgets/widgets.g.dart';
import 'list_todo_screen.dart';

class ListTodoCard extends StatelessWidget {
  final ToDo todo;

  const ListTodoCard({required this.todo, super.key});

  @override
  Widget build(BuildContext context) => HMBColumn(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      HMBRow(
        children: [
          if (todo.parentType == null) const HMBChip(label: 'Personal'),
          if (todo.parentType == ToDoParentType.job)
            HMBEntityChip.job(id: todo.parentId!, format: (job) => job.summary),
          if (todo.parentType == ToDoParentType.customer)
            HMBEntityChip.customer(
              id: todo.parentId!,
              format: (customer) => customer.name,
            ),
          HMBChip(label: 'Priority: ${todo.priority.name}'),
        ],
      ),
      if (todo.parentType == ToDoParentType.job)
        HMBButton.small(
          label: 'Convert to Task',
          hint: 'Covert the todo item into a Job Task',
          onPressed: () => DaoToDo().convertToTask(todo),
        ),
      HMBRow(
        children: [
          if (todo.dueDate != null)
            HMBChip(
              label: formatDue(todo.dueDate!), // Overdue/Today/Thu 09:00
              tone: dueTone(todo.dueDate), // red/purple/neutral
            ),
          _buildSnooze(context),
        ],
      ),
      if (Strings.isNotBlank(todo.note)) HMBTextBlock(todo.note!, maxLines: 4),
    ],
  );

  HMBMenuChip<SnoozeOption> _buildSnooze(BuildContext context) =>
      HMBMenuChip<SnoozeOption>(
        label: 'Snooze',
        icon: Icons.snooze,
        tone: HMBChipTone.accent,
        values: SnoozeOption.values,
        format: (o) => o.description,
        itemIcon: (o) => o.icon,
        onSelected: (o) async {
          var duration = o.duration;
          if (duration == null) {
            // For "Pick…": compute base (same logic your DAO uses)
            final base = todo.dueDate ?? DateTime.now();
            duration = await HMBSnoozePicker.pickSnoozeDuration(
              context,
              base: base,
              initial: base.add(const Duration(hours: 2)),
            );
          }

          if (duration != null) {
            await DaoToDo().snooze(todo, o.duration!);
          }
        },
      );
}
