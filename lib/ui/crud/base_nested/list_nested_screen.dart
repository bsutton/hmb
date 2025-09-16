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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../../dao/dao.dart';
import '../../../dao/notification/dao_june_builder.dart';
import '../../../entity/entity.g.dart';
import '../../dialog/hmb_ask_user_to_continue.dart';
import '../../widgets/hmb_add_button.dart';
import '../../widgets/hmb_icon_button.dart';
import '../../widgets/hmb_toggle.dart';
import '../../widgets/layout/hmb_list_card.dart';

class Parent<P extends Entity<P>> {
  P? parent;

  Parent(this.parent);
}

enum CardDetail { full, summary }

typedef Allowed<C> = bool Function(C entity);

class NestedEntityListScreen<C extends Entity<C>, P extends Entity<P>>
    extends StatefulWidget {
  final Parent<P> parent;
  final String entityNamePlural;
  final Widget Function(C entity) title;
  final Widget Function(P entity)? filterBar;
  final Widget Function(C entity, CardDetail cardDetail) details;
  final Widget Function(C? entity) onEdit;
  final bool Function(C)? canEdit;
  final bool Function(C)? canDelete;
  final Future<void> Function(C entity) onDelete;
  final Future<List<C>> Function() fetchList;
  final Dao<C> dao;
  final String parentTitle;
  final String entityNameSingular;
  final double cardHeight;

  /// All cards are displayed on screen rather than in a listview.
  final bool extended;

  const NestedEntityListScreen({
    required this.dao,
    required this.onEdit,
    required this.onDelete,
    required this.entityNamePlural,
    required this.title,
    required this.details,
    required this.parentTitle,
    required this.entityNameSingular,
    required this.parent,
    required this.fetchList,
    this.filterBar,
    this.canEdit,
    this.canDelete,
    this.extended = false,
    this.cardHeight = 212,
    super.key,
  });

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
  Widget build(BuildContext context) =>
      Column(children: [_buildTitle(), _buildBody()]);

  Widget _buildAddButton(BuildContext context) => HMBButtonAdd(
    enabled: widget.parent.parent != null,
    onAdd: () async {
      if (context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (context) => widget.onEdit(null)),
        ).then((_) => _refreshEntityList());
      }
    },
  );

  Column _buildTitle() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(children: [const Spacer(), _buildFilter(), _buildAddButton(context)]),
    ],
  );

  Widget _buildFilter() => Column(
    mainAxisAlignment: MainAxisAlignment.end,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      HMBToggle(
        label: 'Show details',
        hint: 'Show/Hide full card details',
        initialValue: cardDetail == CardDetail.full,
        onToggled: (on) {
          setState(() {
            cardDetail = on ? CardDetail.full : CardDetail.summary;
          });
        },
      ),
      if (widget.filterBar != null && widget.parent.parent != null)
        widget.filterBar!(widget.parent.parent!),
    ],
  );

  Widget _buildBody() => DaoJuneBuilder.builder(
    widget.dao,
    builder: (context) {
      // return const HMBSpacer(height: true);
      // ignore: discarded_futures
      entities = _fetchList();
      return FutureBuilderEx<List<C>>(
        future: entities,
        waitingBuilder: (_) => const Center(child: CircularProgressIndicator()),
        builder: (context, list) {
          if (widget.parent.parent == null) {
            return Center(
              child: Text(
                'Save the ${widget.parentTitle} first.',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }
          if (list!.isEmpty) {
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

                  Text('to add a ${widget.entityNameSingular}.'),
                ],
              ),
            );
          } else {
            return _displayColumn(list, context);
          }
        },
      );
    },
  );

  Widget _displayColumn(List<C> list, BuildContext context) {
    final cards = <Widget>[];

    for (final entity in list) {
      cards.add(
        SizedBox(height: widget.cardHeight, child: _buildCard(entity, context)),
      );
    }

    return Column(mainAxisSize: MainAxisSize.min, children: cards);
  }

  Widget _buildCard(C entity, BuildContext context) => HMBCrudListCard(
    title: widget.title(entity),
    // ignore: unnecessary_async
    onDelete: () async => _confirmDelete(entity),
    onEdit: () => widget.onEdit(entity),
    canEdit: () => widget.canEdit?.call(entity) ?? true,
    canDelete: () => widget.canDelete?.call(entity) ?? true,
    onRefresh: _refreshEntityList,
    child: Padding(
      padding: const EdgeInsets.only(left: 8),
      child: widget.details(entity, cardDetail),
    ),
  );

  Future<void> _confirmDelete(C entity) async {
    await askUserToContinue(
      context: context,
      title: 'Delete Confirmation',
      message: 'Are you sure you want to delete this item?',
      onConfirmed: () => _delete(entity),
    );
  }

  Future<void> _delete(C entity) async {
    await widget.onDelete(entity);
    await _refreshEntityList();
  }
}
