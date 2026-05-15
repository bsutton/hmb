import 'package:flutter/material.dart';

import '../../../dao/dao_todo.dart';
import '../../../entity/job.dart';
import '../../../entity/todo.dart';
import '../../widgets/widgets.g.dart';

enum PostJobTodoAction { cancel, none, touchBase, schedule }

Future<PostJobTodoAction> promptForPostJobTodo({
  required BuildContext context,
}) async {
  final action = await showDialog<PostJobTodoAction>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Create follow-up todo?'),
      content: const Text('Would you like to add a follow-up todo now?'),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(PostJobTodoAction.cancel),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(PostJobTodoAction.none),
          child: const Text('Skip'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(PostJobTodoAction.touchBase),
          child: const Text('Touch base'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(PostJobTodoAction.schedule),
          child: const Text('Schedule'),
        ),
      ],
    ),
  );

  return action ?? PostJobTodoAction.cancel;
}

Future<void> createPostJobTodo({
  required BuildContext context,
  required Job job,
  required PostJobTodoAction action,
}) async {
  if (action == PostJobTodoAction.cancel || action == PostJobTodoAction.none) {
    return;
  }

  final title = switch (action) {
    PostJobTodoAction.touchBase => 'Touch base with customer',
    PostJobTodoAction.schedule => 'Schedule job',
    PostJobTodoAction.cancel || PostJobTodoAction.none => '',
  };

  final dueDate = switch (action) {
    PostJobTodoAction.touchBase => null,
    PostJobTodoAction.schedule => DateTime.now(),
    PostJobTodoAction.cancel || PostJobTodoAction.none => null,
  };

  final priority = switch (action) {
    PostJobTodoAction.touchBase => ToDoPriority.medium,
    PostJobTodoAction.schedule => ToDoPriority.high,
    PostJobTodoAction.cancel || PostJobTodoAction.none => ToDoPriority.none,
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
