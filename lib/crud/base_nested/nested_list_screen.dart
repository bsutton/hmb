import 'dart:async';

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:june/june.dart';

import '../../dao/dao.dart';
import '../../entity/entities.dart';
import '../../widgets/hmb_add_button.dart';
import '../../widgets/hmb_are_you_sure_dialog.dart';
import '../../widgets/hmb_list_card.dart';

class Parent<P extends Entity<P>> {
  Parent(this.parent);

  P? parent;
}

enum CardDetail { full, summary }

typedef Allowed<C> = bool Function(C entity);

class NestedEntityListScreen<C extends Entity<C>, P extends Entity<P>>
    extends StatefulWidget {
  const NestedEntityListScreen({
    required this.dao,
    required this.onEdit,
    required this.onDelete,
    required this.onInsert,
    required this.entityNamePlural,
    required this.title,
    required this.details,
    required this.parentTitle,
    required this.entityNameSingular,
    required this.parent,
    required this.fetchList,
    this.canEdit,
    this.canDelete,
    this.extended = false,
    super.key,
  });

  final Parent<P> parent;
  final String entityNamePlural;
  final Widget Function(C entity) title;
  final Widget Function(C entity, CardDetail cardDetail) details;
  final Widget Function(C? entity) onEdit;
  final Allowed<C>? canEdit;
  final Allowed<C>? canDelete;
  final Future<void> Function(C? entity) onDelete;
  final Future<void> Function(C? entity) onInsert;
  final Future<List<C>> Function() fetchList;
  final Dao<C> dao;
  final String parentTitle;
  final String entityNameSingular;

  /// All cards are displayed on screen rather than in a listview.
  final bool extended;

  @override
  NestedEntityListScreenState createState() =>
      NestedEntityListScreenState<C, P>();
}

class NestedEntityListScreenState<C extends Entity<C>, P extends Entity<P>>
    extends State<NestedEntityListScreen<C, P>> {
  late Future<List<C>> entities;

  CardDetail cardDetail = CardDetail.summary;

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    // entities = _fetchList();
  }

  Future<void> _refreshEntityList() async {
    if (mounted) {
      setState(() {
        entities = _fetchList();
      });
    }
  }

  Future<List<C>> _fetchList() async {
    if (widget.parent.parent == null) {
      return <C>[];
    } else {
      return widget.fetchList();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false, // No back button
          title: Row(children: [
            Text(
              widget.entityNamePlural,
              style: const TextStyle(fontSize: 18),
            ),
            IconButton(
              tooltip: 'Show/Hide full card details',
              onPressed: () {
                setState(() {
                  cardDetail = cardDetail == CardDetail.full
                      ? CardDetail.summary
                      : CardDetail.full;
                });
              },
              iconSize: 25,
              icon: Icon(cardDetail == CardDetail.full
                  ? Icons.toggle_on
                  : Icons.toggle_off),
            )
          ]),
          actions: [
            HMBButtonAdd(
              enabled: widget.parent.parent != null,
              onPressed: () async {
                if (context.mounted) {
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (context) => widget.onEdit(null)),
                  ).then((_) => _refreshEntityList());
                }
              },
            )
          ],
        ),
        body: JuneBuilder(widget.dao.juneRefresher, builder: (context) {
          // ignore: discarded_futures
          entities = _fetchList();
          return FutureBuilderEx<List<C>>(
            future: entities,
            waitingBuilder: (_) =>
                const Center(child: CircularProgressIndicator()),
            builder: (context, list) {
              if (widget.parent.parent == null) {
                return Center(
                    child: Text(
                  'Save the ${widget.parentTitle} first.',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w500),
                ));
              }
              if (list!.isEmpty) {
                return Center(
                    child: Text(
                  'Click + to add a ${widget.entityNameSingular}.',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w500),
                ));
              } else {
                return widget.extended
                    ? SingleChildScrollView(
                        child: Column(
                          children: list
                              .map((item) => _buildCard(item, context))
                              .toList(),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(2),
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final entity = list[index];
                          return _buildCard(entity, context);
                        },
                      );
              }
            },
          );
        }),
      );

  Widget _buildCard(C entity, BuildContext context) => HMBCrudListCard(
      title: widget.title(entity),
      onDelete: () async => _confirmDelete(entity),
      onEdit: () => widget.onEdit(entity),
      canEdit:
          widget.canEdit == null ? () => true : () => widget.canEdit!(entity),
      canDelete: widget.canDelete == null
          ? () => true
          : () => widget.canDelete!(entity),
      onRefresh: _refreshEntityList,
      child: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: widget.details(entity, cardDetail),
      ));

  Future<void> _confirmDelete(C entity) async {
    await areYouSure(
        context: context,
        title: 'Delete Confirmation',
        message: 'Are you sure you want to delete this item?',
        onConfirmed: () async => _delete(entity));
  }

  Future<void> _delete(C entity) async {
    await widget.onDelete(entity);
    await _refreshEntityList();
  }
}
