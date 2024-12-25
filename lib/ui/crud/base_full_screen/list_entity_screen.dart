import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../../dao/dao.dart';
import '../../../entity/entities.dart';
import '../../../util/app_title.dart';
import '../../dialog/hmb_are_you_sure_dialog.dart';
import '../../widgets/hmb_colours.dart';
import '../../widgets/hmb_search.dart';
import '../../widgets/hmb_toast.dart';
import '../../widgets/layout/hmb_placeholder.dart';
import '../../widgets/surface.dart';

class EntityListScreen<T extends Entity<T>> extends StatefulWidget {
  EntityListScreen({
    required this.dao,
    required this.onEdit,
    required this.pageTitle,
    required this.title,
    required this.details,
    this.cardHeight = 300,
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
  final double cardHeight;

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
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    filterController = TextEditingController();

    setAppTitle(widget.pageTitle);

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
          backgroundColor: SurfaceElevation.e0.color,
          toolbarHeight: 80,
          titleSpacing: 0,
          title: Surface(
              elevation: SurfaceElevation.e0,
              child: HMBSearchWithAdd(onSearch: (newValue) async {
                filterOption = newValue;
                await _refreshEntityList();
              }, onAdd: () async {
                if (context.mounted) {
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (context) => widget.onEdit(null)),
                  ).then((_) => _refreshEntityList());
                }
              })),
          automaticallyImplyLeading: false,
          // actions: _commands(),
        ),
        body: Surface(
          elevation: SurfaceElevation.e0,
          child: FutureBuilderEx<List<T>>(
            future: entities,
            waitingBuilder: (_) => const HMBPlaceHolder(height: 1137),
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
      controller: _scrollController,
      // padding: const EdgeInsets.all(8),

      itemCount: list.length,
      itemExtent: widget.cardHeight,
      itemBuilder: (context, index) {
        final entity = list[index];
        return _buildCard(entity);
      });

  IconButton _buildDeleteButton(T entity) => IconButton(
        icon: const Icon(Icons.delete, color: Colors.red),
        onPressed: () async {
          await _confirmDelete(entity);
        },
      );

  Future<void> _confirmDelete(Entity<T> entity) async {
    await areYouSure(
        context: context,
        title: 'Delete Confirmation',
        message: 'Are you sure you want to delete this item?',
        onConfirmed: () async => _delete(entity));
  }

  Widget _buildCard(T entity) => FutureBuilderEx(
        initialData: HMBColours.cardBackground,
        // ignore: discarded_futures
        future:
            // ignore: discarded_futures
            widget.background?.call(entity) ??
                Future.value(SurfaceElevation.e6.color),
        builder: (context, color) => Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: GestureDetector(
                child: Surface(
                  elevation: SurfaceElevation.e6,
                  child: Column(children: [
                    // contentPadding: const EdgeInsets.all(24),
                    // widget.title(entity),
                    // title:
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: widget.title(entity),
                        ),
                        _buildDeleteButton(entity),
                      ],
                    ),
                    // subtitle: widget.subtile
                    // visualDensity: const VisualDensity(horizontal: -4),
                    // main body of the card
                    // subtitle:

                    widget.details(entity),
                  ]),
                ),
                onTap: () async {
                  // Display the edit crud.
                  if (context.mounted) {
                    await Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                          builder: (context) => widget.onEdit(entity)),
                    ).then((_) => _refreshEntityList());
                  }
                })),
      );

  @override
  void dispose() {
    filterController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _delete(Entity<T> entity) async {
    try {
      await widget.dao.delete(entity.id);
      await _refreshEntityList();
    }
    // ignore: avoid_catches_without_on_clauses
    catch (e) {
      HMBToast.error(e.toString());
    }
  }
}
