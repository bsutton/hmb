import 'package:fixed/fixed.dart';
import 'package:flutter/material.dart';

import '../../dao/dao_checklist_item.dart';
import '../../dao/join_adaptors/dao_join_adaptor.dart';
import '../../entity/check_list_item.dart';
import '../../entity/check_list_item_type.dart';
import '../../entity/entity.dart';
import '../../util/money_ex.dart';
import '../../widgets/hmb_fixed.dart';
import '../../widgets/hmb_money.dart';
import '../../widgets/hmb_text_field.dart';
import '../base_nested/nested_list_screen.dart';
import 'checklist_item_edit_screen.dart';

class CheckListItemListScreen<P extends Entity<P>> extends StatelessWidget {
  const CheckListItemListScreen({
    required this.parent,
    required this.daoJoin,
    super.key,
    this.checkListItemType,
  });

  final Parent<P> parent;

  final DaoJoinAdaptor<CheckListItem, P> daoJoin;
  final CheckListItemType? checkListItemType;

  @override
  Widget build(BuildContext context) => NestedEntityListScreen<CheckListItem,
          P>(
      parent: parent,
      parentTitle: 'Task',
      entityNameSingular: 'Check List Item',
      entityNamePlural: 'Items',
      dao: DaoCheckListItem(),
      onDelete: (checklistitem) async =>
          daoJoin.deleteFromParent(checklistitem!, parent.parent!),
      onInsert: (checklistitem) async =>
          daoJoin.insertForParent(checklistitem!, parent.parent!),
      // ignore: discarded_futures
      fetchList: () => daoJoin.getByParent(parent.parent),
      title: (checklistitem) => Text(checklistitem.description) as Widget,
      onEdit: (checklistitem) => CheckListItemEditScreen(
            daoJoin: daoJoin,
            parent: parent.parent!,
            checkListItem: checklistitem,
          ),
      details: (entity, details) {
        final checklistitem = entity;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, 
        mainAxisSize: MainAxisSize.min,
        children: [
          HMBMoney(label: 'Cost', amount: checklistitem.unitCost),
          HMBFixed(label: 'Quantity', amount: checklistitem.quantity),
          if (checklistitem.completed)
            const Text(
              'Completed',
              style: TextStyle(color: Colors.green),
            )
          else
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              onPressed: () async => _markAsCompleted(context, checklistitem),
            ),
        ]);
      });

  Future<void> _markAsCompleted(
      BuildContext context, CheckListItem item) async {
    final costController = TextEditingController()
      ..text = item.unitCost.toString();

    final quantityController = TextEditingController()
      ..text =
          (item.quantity == Fixed.zero ? Fixed.one : item.quantity).toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HMBTextField(
              controller: costController,
              labelText: 'Cost per item (optional)',
              keyboardType: TextInputType.number,
            ),
            HMBTextField(
              controller: quantityController,
              labelText: 'Quantity (optional)',
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      final quantity = Fixed.tryParse(quantityController.text) ?? Fixed.one;
      final unitCost = MoneyEx.tryParse(costController.text);

      await DaoCheckListItem().markAsCompleted(item, unitCost, quantity);
    }
  }
}
