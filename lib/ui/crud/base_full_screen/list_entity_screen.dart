/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'dart:async';

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart' hide StatefulBuilder;
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../../dao/dao.dart';
import '../../../entity/entity.g.dart';
import '../../../util/app_title.dart';
import '../../../util/util.g.dart';
import '../../dialog/dialog.g.dart';
import '../../widgets/select/hmb_filter_line.dart';
import '../../widgets/widgets.g.dart';

/// A generic list screen with optional search/add and advanced filters.
class EntityListScreen<T extends Entity<T>> extends StatefulWidget {
  EntityListScreen({
    required this.dao,
    required this.onEdit,
    required this.pageTitle,
    required this.title,
    required this.details,

    /// Only implement onAdd if you need to override the default
    /// behavour (such as showing your own UI)
    /// when adding a new entity - normally an entity is created
    /// and then [onEdit] is called.
    this.onAdd,
    this.canAdd = true,

    /// Only implement onDelete if you need to override the default
    /// behavour (such as showing your own UI)
    /// when adding a deleting an entity
    /// Return true if the delete occured
    this.onDelete,
    this.cardHeight = 300,
    this.background,
    Future<List<T>> Function(String? filter)? fetchList,

    /// If non-null, enables advanced filtering via this sheet.
    this.filterSheetBuilder,
    this.onFilterSheetClosed,

    /// Called when the user clears all filters.
    this.onFiltersCleared,
    this.isFilterActive,
    super.key,
    this.showBackButton = false,
  }) {
    // ignore: discarded_futures
    _fetchList = fetchList ?? (_) => dao.getAll();
  }

  final String pageTitle;
  final FutureOr<Widget> Function(T entity) title;
  final Widget Function(T entity) details;
  final Future<T?> Function()? onAdd;
  final Future<bool> Function(T entity)? onDelete;
  final Widget Function(T? entity) onEdit;
  final Future<Color> Function(T entity)? background;
  final double cardHeight;

  final bool canAdd;

  late final Future<List<T>> Function(String? filter) _fetchList;
  final Dao<T> dao;
  final FilterSheetBuilder? filterSheetBuilder;
  final VoidCallback? onFiltersCleared;
  final VoidCallback? onFilterSheetClosed;
  final BoolCallback? isFilterActive;

  /// show the back arrow at the top of the screen.
  /// Used when the EntityList is shown from mini-dashboard
  /// to make back navigation clear.
  final bool showBackButton;

  @override
  EntityListScreenState<T> createState() => EntityListScreenState<T>();
}

class EntityListScreenState<T extends Entity<T>>
    extends DeferredState<EntityListScreen<T>> {
  List<T> entityList = [];
  String? filterOption;
  late final TextEditingController filterController;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    filterController = TextEditingController();

    setAppTitle(widget.pageTitle);
  }

  @override
  Future<void> asyncInitState() async {
    await refresh();
  }

  Future<void> refresh() async {
    final list = await widget._fetchList(filterOption);
    if (mounted) {
      setState(() {
        entityList = list;
      });
    }
  }

  /// Insert or update a **single** entity in memory (partial refresh).
  void _partialRefresh(T updatedEntity) {
    final idx = entityList.indexWhere((e) => e.id == updatedEntity.id);
    setState(() {
      if (idx == -1) {
        // If it's a newly created entity, add it
        entityList.insert(0, updatedEntity);
      } else {
        // If it's an existing entity, update in-place
        entityList[idx] = updatedEntity;
      }
    });
  }

  /// Remove the entity from our in-memory list.
  void _removeFromList(T entity) {
    setState(() {
      entityList.removeWhere((e) => e.id == entity.id);
    });
  }

  Future<void> _clearAll() async {
    widget.onFiltersCleared?.call();
    filterOption = null;
    await refresh();
  }

  final _filterSheetKey = GlobalKey<_FilterSheetState>();

  @override
  Widget build(BuildContext context) {
    final Widget searchAdd;

    searchAdd = HMBSearchWithAdd(
      onSearch: (newValue) async {
        filterOption = newValue;
        await refresh();
      },
      showAdd: widget.canAdd,
      onAdd: () async {
        T? newEntity;
        if (widget.onAdd != null) {
          newEntity = await widget.onAdd!.call();
        } else if (context.mounted) {
          newEntity = await Navigator.push<T?>(
            context,
            MaterialPageRoute(builder: (context) => widget.onEdit(null)),
          );
        }
        if (newEntity != null) {
          _partialRefresh(newEntity);
        }
      },
    );

    Widget titleRow;
    if (widget.filterSheetBuilder != null) {
      titleRow = HMBFilterLine(
        lineBuilder: (_) => searchAdd,
        sheetBuilder: (context) => FilterSheet(
          sheetBuilder: widget.filterSheetBuilder!,
          onChange: () async {
            _filterSheetKey.currentState!.refresh();
            await refresh();
          },
          key: _filterSheetKey,
        ),

        onClearAll: _clearAll,
        onSheetClosed: widget.onFilterSheetClosed,
        isActive: () => widget.isFilterActive?.call() ?? false,
      );
    } else {
      titleRow = searchAdd;
    }

    return Surface(
      elevation: SurfaceElevation.e0,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: SurfaceElevation.e0.color,
          toolbarHeight: 80,
          titleSpacing: 0,
          title: titleRow,
          automaticallyImplyLeading: widget.showBackButton,
        ),
        body: _buildList(),
      ),
    );
  }

  Widget _buildList() {
    if (entityList.isEmpty) {
      if (widget.canAdd) {
        return Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Click'),
              HMBIconButton(
                enabled: false,
                size: HMBIconButtonSize.small,
                icon: const Icon(Icons.add),
                hint: 'Not this one',
                onPressed: () async {},
              ),

              Text('to add ${widget.pageTitle}.'),
            ],
          ),
        );
      } else {
        return Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('No items found. Check the Filter '),
              HMBIconButton(
                enabled: false,
                size: HMBIconButtonSize.small,
                icon: const Icon(Icons.tune),
                hint:
                    'Click the Filter Icon in the top right hand corner to view active filters',
                onPressed: () async {},
              ),
            ],
          ),
        );
      }
    }
    return ListView.builder(
      controller: _scrollController,
      itemCount: entityList.length,
      itemExtent: widget.cardHeight,
      itemBuilder: (context, index) => _buildCard(entityList[index]),
    );
  }

  Widget _buildDeleteButton(T entity) => HMBIconButton(
    icon: const Icon(Icons.delete, color: Colors.red),
    showBackground: false,
    onPressed: () async {
      await _confirmDelete(entity);
    },
    hint: 'Delete',
  );

  Widget _buildCard(T entity) => FutureBuilderEx<Color>(
    initialData: SurfaceElevation.e6.color,
    future:
        // ignore: discarded_futures
        widget.background?.call(entity) ??
        Future.value(SurfaceElevation.e6.color),
    builder: (context, cardColor) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GestureDetector(
        onTap: () async {
          // Navigate to the edit screen
          final updatedEntity = await Navigator.push<T?>(
            context,
            MaterialPageRoute(builder: (context) => widget.onEdit(entity)),
          );
          // If user successfully saved or created a new entity
          if (updatedEntity != null) {
            _partialRefresh(updatedEntity);
          }
        },
        child: Surface(
          elevation: SurfaceElevation.e6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: FutureBuilderEx(
                      future:
                          ((widget.title is Future)
                                  // ignore: discarded_futures
                                  ? widget.title(entity)
                                  // ignore: discarded_futures
                                  : Future.value(widget.title(entity)))
                              as Future<Widget>,
                      builder: (context, title) => title!,
                    ),
                  ),
                  _buildDeleteButton(entity),
                ],
              ),
              // Body (details)
              Expanded(child: widget.details(entity)),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _confirmDelete(T entity) async {
    await askUserToContinue(
      context: context,
      title: 'Delete Confirmation',
      message: 'Are you sure you want to delete this item?',
      onConfirmed: () => _delete(entity),
    );
  }

  @override
  void dispose() {
    filterController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _delete(T entity) async {
    var remove = false;
    try {
      if (widget.onDelete != null) {
        remove = await widget.onDelete!.call(entity);
      } else {
        await widget.dao.delete(entity.id);
        remove = true;
      }
      if (remove) {
        _removeFromList(entity);
      }
    }
    // ignore: avoid_catches_without_on_clauses
    catch (e) {
      HMBToast.error(e.toString());
    }
  }
}

typedef FilterSheetBuilder = Widget Function(void Function() onChange);

class FilterSheet extends StatefulWidget {
  const FilterSheet({
    required this.sheetBuilder,
    required this.onChange,
    super.key,
  });

  final FilterSheetBuilder sheetBuilder;
  final void Function() onChange;

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  final _stateBuilderKey = GlobalKey<StatefulBuilderState>();
  @override
  Widget build(BuildContext context) => StatefulBuilder(
    key: _stateBuilderKey,
    builder: (context, setState) => widget.sheetBuilder(widget.onChange),
  );

  /// cause the fitler sheet to rebuild.
  void refresh() {
    _stateBuilderKey.currentState!.setState(() {});
  }
}
