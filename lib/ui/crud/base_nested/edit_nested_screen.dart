import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../../../dao/dao.dart';
import '../../../entity/entity.dart';
import '../../widgets/hmb_toast.dart';
import '../../widgets/save_and_close.dart';

abstract class NestedEntityState<E extends Entity<E>> {
  Future<E> forInsert();
  Future<E> forUpdate(E entity);
  void refresh();
  E? currentEntity;
  Future<void> postSave(Transaction transaction, Operation operation);
}

enum Operation { insert, update }

class NestedEntityEditScreen<C extends Entity<C>, P extends Entity<P>>
    extends StatefulWidget {
  const NestedEntityEditScreen({
    required this.editor,
    required this.onInsert,
    required this.entityName,
    required this.entityState,
    required this.dao,
    super.key,
  });

  final String entityName;
  final Dao<C> dao;
  final Widget Function(C? entity) editor;
  final NestedEntityState<C> entityState;
  final Future<void> Function(C? entity, Transaction transaction) onInsert;

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
    body: Column(
      children: [
        _commandButtons(context),
        Flexible(
          child: Form(
            key: _formKey,
            child: Column(
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
    if (_formKey.currentState!.validate()) {
      try {
        if (widget.entityState.currentEntity != null) {
          final updatedEntity = await widget.entityState.forUpdate(
            widget.entityState.currentEntity!,
          );

          await widget.dao.withTransaction((transaction) async {
            await widget.dao.update(updatedEntity, transaction);
            await widget.entityState.postSave(transaction, Operation.update);
            setState(() {
              widget.entityState.currentEntity = updatedEntity;
            });
          });
        } else {
          final newEntity = await widget.entityState.forInsert();

          await widget.dao.withTransaction((transaction) async {
            await widget.onInsert(newEntity, transaction);
            await widget.entityState.postSave(transaction, Operation.insert);
            setState(() {
              widget.entityState.currentEntity = newEntity;
            });
          });
        }

        if (close && mounted) {
          widget.entityState.refresh();
          Navigator.of(context).pop(widget.entityState.currentEntity);
        } else {
          setState(() {});
        }
      } catch (error) {
        // Check if the error indicates a duplicate name (unique constraint violation)
        if (error.toString().contains('UNIQUE constraint failed')) {
          HMBToast.error(
            'A ${widget.entityName.toLowerCase()} with that name already exists.',
          );
        } else {
          rethrow;
        }
      }
    }
  }
}
