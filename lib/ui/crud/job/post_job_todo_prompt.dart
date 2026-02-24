import 'package:flutter/material.dart';

import '../../../dao/dao_todo.dart';
import '../../../entity/job.dart';
import '../../../entity/todo.dart';
import '../../widgets/widgets.g.dart';

enum _PostJobTodoAction { none, touchBase, schedule }

Future<void> promptForPostJobTodo({
  required BuildContext context,
  required Job job,
}) async {
  final action = await showDialog<_PostJobTodoAction>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Create follow-up todo?'),
      content: const Text('Would you like to add a follow-up todo now?'),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(_PostJobTodoAction.none),
          child: const Text('Skip'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(_PostJobTodoAction.touchBase),
          child: const Text('Touch base'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(_PostJobTodoAction.schedule),
          child: const Text('Schedule'),
        ),
      ],
    ),
  );

  if (action == null || action == _PostJobTodoAction.none) {
    return;
  }

  final title = switch (action) {
    _PostJobTodoAction.touchBase => 'Touch base with customer',
    _PostJobTodoAction.schedule => 'Schedule job',
    _PostJobTodoAction.none => '',
  };

  final dueDate = switch (action) {
    _PostJobTodoAction.touchBase => null,
    _PostJobTodoAction.schedule => DateTime.now(),
    _PostJobTodoAction.none => null,
  };

  final priority = switch (action) {
    _PostJobTodoAction.touchBase => ToDoPriority.medium,
    _PostJobTodoAction.schedule => ToDoPriority.high,
    _PostJobTodoAction.none => ToDoPriority.none,
  };

  try {
    await DaoToDo().insert(
      ToDo.forInsert(
        title: title,
        dueDate: dueDate,
        priority: priority,
        parentType: ToDoParentType.job,
        parentId: job.id,
      ),
    );
    if (context.mounted) {
      HMBToast.info('Todo created');
    }
  } catch (e) {
    if (context.mounted) {
      HMBToast.error('Failed to create todo: $e');
    }
  }
}
