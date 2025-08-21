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

import 'package:flutter/material.dart';

import '../../../dao/dao.dart';
import '../../../entity/entity.dart';
import '../../widgets/hmb_toast.dart';
import '../../widgets/save_and_close.dart';

abstract class EntityState<E extends Entity<E>> {
  Future<E> forInsert();
  Future<E> forUpdate(E entity);

  /// Called to notify that the entity has just been saved.
  /// [currentEntity] will have the saved value.
  Future<void> postSave(E entity);
  E? currentEntity;
}

typedef CrossValidator<E> = Future<bool> Function();
Future<bool> noOpValidator() async => true;

/// The [crossValidator] is called during the save operation
/// after the Form has been validated to allow you to cross
/// validate form fields. If there is an error you should display it
/// as this class will NOT.
class EntityEditScreen<E extends Entity<E>> extends StatefulWidget {
  final String entityName;
  final Dao<E> dao;

  /// Overload [preSave] if you need to take an action before
  /// saving the entity and optionally abort the save.
  /// This method is called after the form has been validated
  /// and the new/updated entity assembled.
  final Future<bool> Function(E entity)? preSave;
  final Widget Function(E? entity, {required bool isNew}) editor;
  final EntityState<E> entityState;
  final ScrollController? scrollController;
  final Future<bool> Function() crossValidator;

  const EntityEditScreen({
    required this.editor,
    required this.entityName,
    required this.entityState,
    required this.dao,
    this.preSave,
    this.scrollController,
    CrossValidator<E>? crossValidator,
    super.key,
  }) : crossValidator = crossValidator ?? noOpValidator;

  @override
  EntityEditScreenState createState() => EntityEditScreenState<E>();
}

class EntityEditScreenState<E extends Entity<E>>
    extends State<EntityEditScreen<E>> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.entityState.currentEntity != null
            ? 'Edit ${widget.entityName}'
            : 'Add ${widget.entityName}',
      ),
    ),
    body: Padding(
      padding: const EdgeInsets.all(4),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _commandButtons(context),

            /// Inject the entity-specific editor.
            Expanded(
              child: SingleChildScrollView(
                key: PageStorageKey(
                  /// the entity id's are not unique across tables
                  /// so we use the createdDate which is in reality
                  /// unique in all realworld scenarios.
                  widget.entityState.currentEntity?.createdDate,
                ),
                // controller: widget.scrollController ??
                //     ScrollController(), // Attach the controller here
                padding: const EdgeInsets.all(4),
                child: widget.editor(
                  widget.entityState.currentEntity,
                  isNew: isNew,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  /// Display the Save/Cancel Buttons.
  Widget _commandButtons(BuildContext context) => SaveAndClose(
    onSave: _save,
    showSaveOnly: isNew,
    onCancel: () async {
      Navigator.of(context).pop();
    },
  );
  Future<void> _save({bool close = false}) async {
    if (_formKey.currentState!.validate() && await widget.crossValidator()) {
      try {
        if (widget.entityState.currentEntity != null) {
          // Update existing entity
          final updatedEntity = await widget.entityState.forUpdate(
            widget.entityState.currentEntity!,
          );
          if (widget.preSave == null ||
              (await widget.preSave!(updatedEntity))) {
            await widget.dao.update(updatedEntity);
            widget.entityState.currentEntity = updatedEntity;
          }
        } else {
          // Insert new entity
          final newEntity = await widget.entityState.forInsert();
          if (widget.preSave == null || (await widget.preSave!(newEntity))) {
            await widget.dao.insert(newEntity);
            widget.entityState.currentEntity = newEntity;
          }
        }
        await saved();

        if (close && mounted) {
          Navigator.of(context).pop(widget.entityState.currentEntity);
        }
      } catch (error) {
        // Check if the error indicates a duplicate name (unique
        //constraint violation)
        if (error.toString().contains('UNIQUE constraint failed')) {
          HMBToast.error(
            '''A ${widget.entityName.toLowerCase()} with that name already exists.''',
          );
        } else {
          HMBToast.error(error.toString());
        }
      }
    }
  }

  Future<void> saved() async {
    await widget.entityState.postSave(widget.entityState.currentEntity!);
    setState(() {});
  }

  bool get isNew => widget.entityState.currentEntity == null;
}
