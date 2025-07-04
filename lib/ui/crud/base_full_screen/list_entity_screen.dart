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
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../../dao/dao.dart';
import '../../../entity/entity.g.dart';
import '../../../util/app_title.dart';
import '../../dialog/hmb_ask_user_to_continue.dart';
import '../../widgets/hmb_icon_button.dart';
import '../../widgets/hmb_search.dart';
import '../../widgets/hmb_toast.dart';
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
    // ignore: discarded_futures
    _fetchList = fetchList ?? (_) => dao.getAll();
  }

  final String pageTitle;
  final FutureOr<Widget> Function(T entity) title;
  final Widget Function(T entity) details;
  final Widget Function(T? entity) onEdit;
  final Future<Color> Function(T entity)? background;
  final double cardHeight;

  late final Future<List<T>> Function(String? filter) _fetchList;
  final Dao<T> dao;

  @override
  EntityListScreenState<T> createState() => EntityListScreenState<T>();
}

class EntityListScreenState<T extends Entity<T>>
    extends DeferredState<EntityListScreen<T>> {
  late List<T> entityList = [];
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
    await _fetchEntities();
  }

  Future<void> _fetchEntities([String? filter]) async {
    final list = await widget._fetchList(filter);
    if (mounted) {
      setState(() {
        entityList = list;
      });
    }
  }

  /// Called when we want to refresh the entire list (e.g., after the user searches).
  Future<void> _refreshEntityList() async {
    // Re-fetch from the database (or custom fetch) with the current filter.
    if (mounted) {
      await _fetchEntities(filterOption);
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: SurfaceElevation.e0.color,
      toolbarHeight: 80,
      titleSpacing: 0,
      title: Surface(
        elevation: SurfaceElevation.e0,
        child: HMBSearchWithAdd(
          onSearch: (newValue) async {
            filterOption = newValue;
            await _refreshEntityList();
          },
          onAdd: () async {
            if (context.mounted) {
              final newEntity = await Navigator.push<T?>(
                context,
                MaterialPageRoute(builder: (context) => widget.onEdit(null)),
              );
              if (newEntity != null) {
                _partialRefresh(newEntity);
              }
            }
          },
        ),
      ),
      automaticallyImplyLeading: false,
      // actions: _commands(),
    ),
    body: Surface(elevation: SurfaceElevation.e0, child: _buildList()),
  );

  Widget _buildList() {
    if (entityList.isEmpty) {
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
    }
    return ListView.builder(
      controller: _scrollController,
      itemCount: entityList.length,
      itemExtent: widget.cardHeight,
      itemBuilder: (context, index) {
        final entity = entityList[index];
        return _buildCard(entity);
      },
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
      padding: const EdgeInsets.only(top: 8, bottom: 8),
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
    try {
      await widget.dao.delete(entity.id);
      _removeFromList(entity);
    }
    // ignore: avoid_catches_without_on_clauses
    catch (e) {
      HMBToast.error(e.toString());
    }
  }
}
