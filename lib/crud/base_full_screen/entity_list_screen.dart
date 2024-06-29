import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../dao/dao.dart';
import '../../entity/entities.dart';
import '../../widgets/hmb_add_button.dart';
import '../../widgets/hmb_are_you_sure_dialog.dart';
import '../../widgets/hmb_text_field.dart';

class EntityListScreen<T extends Entity<T>> extends StatefulWidget {
  EntityListScreen({
    required this.dao,
    required this.onEdit,
    required this.pageTitle,
    required this.title,
    required this.details,
    this.background,
    Future<List<T>> Function(String? filter)? fetchList,
    super.key,
  }) {
    _fetchList = fetchList ?? (_) async => dao.getAll();
  }

  final String pageTitle;
  final Widget Function(T entity) title;
  final Widget Function(T entity) details;
  final Widget Function(T? entity) onEdit;
  final Future<Color> Function(T entity)? background;

  late final Future<List<T>> Function(String? filter) _fetchList;
  final Dao<T> dao;

  @override
  EntityListScreenState createState() => EntityListScreenState<T>();
}

class EntityListScreenState<T extends Entity<T>>
    extends State<EntityListScreen<T>> {
  late Future<List<T>> entities;
  String? filterOption;
  late final TextEditingController filterController;

  @override
  void initState() {
    super.initState();
    filterController = TextEditingController();
    // ignore: discarded_futures
    entities = widget._fetchList(null);
  }

  Future<void> _refreshEntityList() async {
    if (mounted) {
      setState(() {
        entities = widget._fetchList(filterOption);
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.pageTitle),
          actions: _commands(),
        ),
        body: Padding(
          padding: const EdgeInsets.all(8),
          child: FutureBuilderEx<List<T>>(
            future: entities,
            waitingBuilder: (_) =>
                const Center(child: CircularProgressIndicator()),
            builder: (context, list) {
              if (list == null || list.isEmpty) {
                return Center(
                  child: Text(
                    'Click + to add ${widget.pageTitle}.',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                );
              } else {
                return _buildListTiles(list);
              }
            },
          ),
        ),
      );

  Widget _buildListTiles(List<T> list) => ListView.builder(
        // padding: const EdgeInsets.all(8),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final entity = list[index];
          return FutureBuilderEx(
              // ignore: discarded_futures
              future:
                  // ignore: discarded_futures
                  widget.background?.call(entity) ?? Future.value(Colors.white),
              builder: (context, color) => Card(
                    color: color,
                    // margin: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 2,
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(4),
                      // widget.title(entity),
                      title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            widget.title(entity),
                            _buildDeleteButton(entity)
                          ]),
                      // subtitle: widget.subtile
                      visualDensity: const VisualDensity(horizontal: -4),
                      subtitle: widget.details(entity),
                      onTap: () async {
                        if (context.mounted) {
                          await Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                                builder: (context) => widget.onEdit(entity)),
                          ).then((_) => _refreshEntityList());
                        }
                      },
                    ),
                  ));
        },
      );

  IconButton _buildDeleteButton(T entity) => IconButton(
        icon: const Icon(Icons.delete, color: Colors.red),
        onPressed: () async {
          await _confirmDelete(entity);
        },
      );

  List<Widget> _commands() => [
        SizedBox(
          width: 250,
          child: HMBTextField(
            leadingSpace: false,
            labelText: 'Filter',
            controller: filterController,
            onChanged: (newValue) async {
              filterOption = newValue;
              await _refreshEntityList();
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () async {
            filterController.clear();
            filterOption = null;
            await _refreshEntityList();
          },
        ),
        HMBButtonAdd(
          enabled: true,
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
      ];

  Future<void> _confirmDelete(Entity<T> entity) async {
    await areYouSure(
        context: context,
        title: 'Delete Confirmation',
        message: 'Are you sure you want to delete this item?',
        onConfirmed: () async => _delete(entity));
  }

  @override
  void dispose() {
    filterController.dispose();
    super.dispose();
  }

  Future<void> _delete(Entity<T> entity) async {
    await widget.dao.delete(entity.id);
    await _refreshEntityList();
  }
}
