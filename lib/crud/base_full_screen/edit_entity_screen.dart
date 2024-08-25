import 'package:flutter/material.dart';

import '../../dao/dao.dart';
import '../../entity/entity.dart';
import '../../widgets/hmb_button.dart';

abstract class EntityState<E extends Entity<E>> {
  Future<E> forInsert();
  Future<E> forUpdate(E entity);
  void refresh();
}

class EntityEditScreen<E extends Entity<E>> extends StatefulWidget {
  const EntityEditScreen({
    required this.entity,
    required this.editor,
    required this.entityName,
    required this.entityState,
    required this.dao,
    super.key,
  });

  final E? entity;
  final String entityName;
  final Dao<E> dao;

  final Widget Function(E? entity) editor;
  final EntityState<E> entityState;

  @override
  EntityEditScreenState createState() => EntityEditScreenState<E>();
}

/// The state of the EntityEditScreen.
class EntityEditScreenState<E extends Entity<E>>
    extends State<EntityEditScreen<E>> {
  final _formKey = GlobalKey<FormState>();

  E? _currentEntity;

  @override
  void initState() {
    super.initState();
    _currentEntity = widget.entity;
  }

  /// Build the entity screen
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(_currentEntity != null
              ? 'Edit ${widget.entityName}'
              : 'Add ${widget.entityName}'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(4),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _commandButtons(context),

                /// Inject the entity specific editor.
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(4),
                    child: widget.editor(_currentEntity),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  /// Display the Save/Cancel Buttons.
  Padding _commandButtons(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            HMBButton(
              onPressed: _save,
              label: 'Save',
            ),
            const SizedBox(width: 5),
            HMBButton(
              label: 'Save & Close',
              onPressed: () async => _save(close: true),
            ),
            const SizedBox(width: 5),
            HMBButton(
              onPressed: () => Navigator.of(context).pop(),
              label: 'Cancel',
            ),
          ],
        ),
      );

  /// Save the entity
  Future<void> _save({bool close = false}) async {
    if (_formKey.currentState!.validate()) {
      if (_currentEntity != null) {
        // Update existing entity
        final updatedEntity =
            await widget.entityState.forUpdate(_currentEntity!);
        await widget.dao.update(updatedEntity);
        setState(() {
          _currentEntity = updatedEntity;
        });
      } else {
        // Insert new entity
        final newEntity = await widget.entityState.forInsert();
        await widget.dao.insert(newEntity);
        setState(() {
          _currentEntity = newEntity;
          // widget.entityState.refresh();
        });
      }

      if (close && mounted) {
        Navigator.of(context).pop(_currentEntity);
      } else {
        setState(() {});
      }
    }
  }
}
