import 'package:flutter/material.dart';

import '../../dao/dao.dart';
import '../../entity/entity.dart';
import '../../widgets/hmb_button.dart';

abstract class NestedEntityState<E extends Entity<E>> {
  Future<E> forInsert();
  Future<E> forUpdate(E entity);
  void refresh();
}

class NestedEntityEditScreen<C extends Entity<C>, P extends Entity<P>>
    extends StatefulWidget {
  const NestedEntityEditScreen({
    required this.entity,
    required this.editor,
    required this.onInsert,
    required this.entityName,
    required this.entityState,
    required this.dao,
    super.key,
  });

  final C? entity;
  final String entityName;
  final Dao<C> dao;
  final Widget Function(C? entity) editor;
  final NestedEntityState<C> entityState;
  final Future<void> Function(C? entity) onInsert;

  @override
  NestedEntityEditScreenState createState() =>
      NestedEntityEditScreenState<C, P>();
}

class NestedEntityEditScreenState<C extends Entity<C>, P extends Entity<P>>
    extends State<NestedEntityEditScreen<C, P>> {
  final _formKey = GlobalKey<FormState>();

  C? _currentEntity;

  @override
  void initState() {
    super.initState();
    _currentEntity = widget.entity;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(_currentEntity != null
              ? 'Edit ${widget.entityName}'
              : 'Add ${widget.entityName}'),
        ),
        body: Column(
          children: [
            _commandButtons(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      /// Inject the entity specific editor.
                      widget.editor(_currentEntity),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  Padding _commandButtons(BuildContext context) => Padding(
      padding: const EdgeInsets.all(16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        HMBButton(
          onPressed: _save,
          label: 'Save',
        ),
        HMBButton(
            label: 'Save & Close', onPressed: () async => _save(close: true)),
        const SizedBox(width: 5),
        const SizedBox(width: 5),
        HMBButton(
          onPressed: () => Navigator.of(context).pop(),
          label: 'Cancel',
        ),
      ]));

  Future<void> _save({bool close = false}) async {
    if (_formKey.currentState!.validate()) {
      if (_currentEntity != null) {
        final updatedEntity =
            await widget.entityState.forUpdate(_currentEntity!);
        await widget.dao.update(updatedEntity);
        setState(() {
          _currentEntity = updatedEntity;
        });
      } else {
        final newEntity = await widget.entityState.forInsert();
        await widget.onInsert(newEntity);
        setState(() {
          _currentEntity = newEntity;
          widget.entityState.refresh();
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
