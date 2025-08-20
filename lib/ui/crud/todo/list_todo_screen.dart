import 'package:flutter/material.dart';

import '../../../dao/dao_todo.dart';
import '../../../entity/todo.dart';
import '../../../util/util.g.dart';
import '../../widgets/text/text.g.dart';
import '../../widgets/widgets.g.dart';
import '../base_full_screen/list_entity_screen.dart';
import 'edit_todo_screen.dart';
import 'list_todo_card.dart';

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
      ],
    ),
    background: (t) async => t.status == ToDoStatus.open && isOverdue(t.dueDate)
        ? SurfaceElevation.e6.color.withSafeOpacity(0.92)
        : SurfaceElevation.e6.color,
    details: (t) => ListTodoCard(todo: t),
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
