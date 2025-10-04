import 'package:flutter/material.dart';

import '../../util/dart/dart.g.dart';
import '../widgets/hmb_button.dart';

/// Show a confirmation dialog before deleting an entity.
/// [onConfirmed] is called if the user confirms the deletion.
///
/// [nameSingular] is the name of the entity being deleted, used
///   in the dialog title and button.
/// [question] is the question to ask the user, defaults to 'Are you sure you
///   want to delete this [nameSingular]?'
/// [child] can be used to provide a custom widget for the dialog
///   content instead of the default question text.
/// Provide either [question] or [child], not both.
Future<void> showConfirmDeleteDialog({
  required BuildContext context,
  required String nameSingular,
  required AsyncVoidCallback onConfirmed,
  Widget? child,
  String? question,
}) async {
  assert(
    (question == null) || (child == null),
    'Provide either question or child, not both.',
  );
  question ??= 'Are you sure you want to delete this $nameSingular?';
  if (context.mounted) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm deletion of $nameSingular'),
        content: child ?? Text(question!),
        actions: <Widget>[
          HMBButton(
            label: 'Cancel',
            hint: "Don't delete the $nameSingular",
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          HMBButton(
            label: 'Delete',
            hint: 'Delete this $nameSingular',
            onPressed: () async {
              await onConfirmed();
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
    );
  }
}
