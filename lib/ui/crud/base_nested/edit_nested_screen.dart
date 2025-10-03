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
import 'package:sqflite_common/sqlite_api.dart';

import '../../../dao/dao.dart';
import '../../../entity/entity.dart';
import '../../widgets/hmb_toast.dart';
import '../../widgets/layout/layout.g.dart' show HMBColumn;
import '../../widgets/save_and_close.dart';
import '../base_full_screen/edit_entity_screen.dart';

abstract class NestedEntityState<E extends Entity<E>> {
  Future<E> forInsert();
  Future<E> forUpdate(E entity);
  void refresh();
  E? currentEntity;
  Future<void> postSave(Transaction transaction, Operation operation);
}

enum Operation { insert, update }

/// The [crossValidator] is called during the save operation
/// after the Form has been validated to allow you to cross
/// validate form fields. If there is an error you should display it
/// as this class will NOT.
class NestedEntityEditScreen<C extends Entity<C>, P extends Entity<P>>
    extends StatefulWidget {
  final String entityName;
  final Dao<C> dao;
  final Widget Function(C? entity) editor;
  final NestedEntityState<C> entityState;
  final Future<void> Function(C? entity, Transaction transaction) onInsert;
  final Future<bool> Function() crossValidator;

  const NestedEntityEditScreen({
    required this.editor,
    required this.onInsert,
    required this.entityName,
    required this.entityState,
    required this.dao,
    CrossValidator<C>? crossValidator,
    super.key,
  }) : crossValidator = crossValidator ?? noOpValidator;

  @override
  NestedEntityEditScreenState createState() =>
      NestedEntityEditScreenState<C, P>();
}

class NestedEntityEditScreenState<C extends Entity<C>, P extends Entity<P>>
    extends State<NestedEntityEditScreen<C, P>> {
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.entityState.currentEntity != null
            ? 'Edit ${widget.entityName}'
            : 'Add ${widget.entityName}',
      ),
      automaticallyImplyLeading: false,
    ),
    body: HMBColumn(
      children: [
        _commandButtons(context),
        Flexible(
          child: Form(
            key: _formKey,
            child: HMBColumn(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(4),

                    /// Inject the entity specific editor.
                    child: widget.editor(widget.entityState.currentEntity),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _commandButtons(BuildContext context) => SaveAndClose(
    onSave: _save,
    showSaveOnly: widget.entityState.currentEntity == null,
    onCancel: () async {
      Navigator.of(context).pop();
    },
  );

  Future<void> _save({bool close = false}) async {
    if (_formKey.currentState!.validate() && await widget.crossValidator()) {
      final savedEntity = widget.entityState.currentEntity;
      try {
        if (widget.entityState.currentEntity != null) {
          final updatedEntity = await widget.entityState.forUpdate(
            widget.entityState.currentEntity!,
          );

          try {
            await widget.dao.withTransaction((transaction) async {
              widget.entityState.currentEntity = updatedEntity;
              await widget.dao.update(updatedEntity, transaction);
              await widget.entityState.postSave(transaction, Operation.update);
            });
          } catch (e) {
            widget.entityState.currentEntity = savedEntity;
            rethrow;
          }

          setState(() {});
        } else {
          final newEntity = await widget.entityState.forInsert();
          widget.entityState.currentEntity = newEntity;

          try {
            await widget.dao.withTransaction((transaction) async {
              await widget.onInsert(newEntity, transaction);
              await widget.entityState.postSave(transaction, Operation.insert);
            });
          } catch (e) {
            widget.entityState.currentEntity = savedEntity;
            rethrow;
          }
          setState(() {});
        }

        if (close && mounted) {
          widget.entityState.refresh();
          Navigator.of(context).pop(widget.entityState.currentEntity);
        } else {
          setState(() {});
        }
      } catch (error) {
        // Check if the error indicates a duplicate name (unique
        //constraint violation)
        if (error.toString().contains('UNIQUE constraint failed')) {
          HMBToast.error(
            '''A ${widget.entityName.toLowerCase()} with that name already exists.''',
          );
        } else {
          rethrow;
        }
      }
    }
  }
}
