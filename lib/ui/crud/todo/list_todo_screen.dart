import 'package:flutter/material.dart';

import '../../../dao/dao_todo.dart';
import '../../../entity/todo.dart';
import '../../../util/util.g.dart';
import '../../dialog/hmb_snooze_picker.dart';
import '../../widgets/hmb_chip.dart';
import '../../widgets/hmb_menu_chip.dart';
import '../../widgets/hmb_select_chips.dart';
import '../../widgets/layout/hmb_spacer.dart';
import '../../widgets/select/hmb_entity_chip.dart';
import '../../widgets/text/text.g.dart';
import '../../widgets/widgets.g.dart';
import '../base_full_screen/list_entity_screen.dart';
import 'edit_todo_screen.dart';

class ToDoListScreen extends StatefulWidget {
  const ToDoListScreen({super.key});

  @override
  State<ToDoListScreen> createState() => _ToDoListScreenState();
}

class _ToDoListScreenState extends State<ToDoListScreen> {
  // Default to showing open items only.
  ToDoStatus toDoListStatusFilter = ToDoStatus.open;

  @override
  Widget build(BuildContext context) => EntityListScreen<ToDo>(
    pageTitle: 'Todo',
    dao: DaoToDo(),
    // Order: overdue first, then today, then upcoming.
    fetchList: (filter) =>
        DaoToDo().getFiltered(filter: filter, status: toDoListStatusFilter),
    filterSheetBuilder: (onChange) => _buildFilterSheet(context, onChange),
    onFilterReset: () => toDoListStatusFilter = ToDoStatus.open,
    isFilterActive: () => toDoListStatusFilter == ToDoStatus.done,
    onEdit: (todo) => ToDoEditScreen(toDo: todo),
    title: (t) => Row(
      children: [
        Checkbox(
          value: t.status == ToDoStatus.done,
          onChanged: (_) async {
            await DaoToDo().toggleDone(t);
          },
        ),
        Expanded(child: HMBTextHeadline2(t.title)),
        if (t.dueDate != null)
          HMBChip(
            label: formatDue(t.dueDate!), // Overdue/Today/Thu 09:00
            tone: dueTone(t.dueDate), // red/purple/neutral
          ),
      ],
    ),
    background: (t) async => t.status == ToDoStatus.open && isOverdue(t.dueDate)
        ? SurfaceElevation.e6.color.withSafeOpacity(0.92)
        : SurfaceElevation.e6.color,
    details: (t) => _buildCard(t, context),
  );

  Column _buildCard(ToDo t, BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (t.note != null) HMBTextBlock(t.note!, maxLines: 4),
      const HMBSpacer(height: true),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (t.parentType == null) const HMBChip(label: 'Personal'),
          if (t.parentType == ToDoParentType.job)
            HMBEntityChip.job(id: t.parentId!, format: (job) => job.summary),
          if (t.parentType == ToDoParentType.customer)
            HMBEntityChip.customer(
              id: t.parentId!,
              format: (customer) => customer.name,
            ),
          HMBChip(label: 'Priority: ${t.priority.name}'),
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
                final base = t.dueDate ?? DateTime.now();
                duration = await HMBSnoozePicker.pickSnoozeDuration(
                  context,
                  base: base,
                  initial: base.add(const Duration(hours: 2)),
                );
              }

              if (duration != null) {
                await DaoToDo().snooze(t, o.duration!);
              }
            },
          ),
          if (t.parentType == ToDoParentType.job)
            HMBButton.small(
              label: 'Convert to Task',
              hint: 'Covert the todo item into a Job Task',
              onPressed: () => DaoToDo().convertToTask(t),
            ),
        ],
      ),
    ],
  );

  Widget _buildFilterSheet(BuildContext context, void Function() onChange) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HMBSelectChips<ToDoStatus>(
            label: 'Status',
            items: ToDoStatus.values,
            value: toDoListStatusFilter,
            onChanged: (v) {
              toDoListStatusFilter = v!;
              onChange();
            },
            format: (status) => status.name,
          ),
        ],
      );
}

enum SnoozeOption {
  todayEve(
    description: 'Today eve',
    icon: Icons.nightlight_round,
    duration: Duration(hours: 4), // adjust for your "evening" logic
  ),
  tomorrow(
    description: 'Tomorrow',
    icon: Icons.wb_sunny,
    duration: Duration(days: 1),
  ),
  nextWeek(
    description: 'Next week',
    icon: Icons.calendar_view_week,
    duration: Duration(days: 7),
  ),
  pick(
    description: 'Pick…',
    icon: Icons.edit_calendar,
    duration: null, // triggers picker
  );

  const SnoozeOption({
    required this.description,
    required this.icon,
    required this.duration,
  });

  final String description;
  final IconData icon;
  final Duration? duration;
}
