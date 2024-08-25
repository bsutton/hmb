// ignore_for_file: library_private_types_in_public_api
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:june/june.dart';
import 'package:strings/strings.dart';

import '../../dao/dao_checklist.dart';
import '../../dao/join_adaptors/dao_join_adaptor.dart';
import '../../dao/join_adaptors/join_adaptor_check_list_item.dart';
import '../../entity/check_list.dart';
import '../../entity/customer.dart';
import '../../entity/entity.dart';
import '../../widgets/hmb_crud_checklist_item.dart';
import '../../widgets/hmb_droplist.dart';
import '../../widgets/hmb_text_field.dart';
import '../base_nested/edit_nested_screen.dart';
import '../base_nested/list_nested_screen.dart';

class CheckListEditScreen<P extends Entity<P>> extends StatefulWidget {
  const CheckListEditScreen({
    required this.parent,
    required this.daoJoin,
    super.key,
    this.checklist,
    this.checkListType,
  });
  final P parent;
  final CheckList? checklist;
  final DaoJoinAdaptor<CheckList, P> daoJoin;
  final CheckListType? checkListType;

  @override
  _CheckListEditScreenState createState() => _CheckListEditScreenState();
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<CheckList?>('CheckList', checklist));
  }
}

class _CheckListEditScreenState extends State<CheckListEditScreen>
    implements NestedEntityState<CheckList> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.checklist?.name);
    _descriptionController =
        TextEditingController(text: widget.checklist?.description);
    June.getState(CheckListTypeStatus.new).checkListType =
        widget.checkListType ?? CheckListType.global;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NestedEntityEditScreen<CheckList, Customer>(
        entity: widget.checklist,
        entityName: 'CheckList',
        dao: DaoCheckList(),
        entityState: this,
        onInsert: (checklist) async =>
            widget.daoJoin.insertForParent(checklist!, widget.parent),
        editor: (checklist) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Add other form fields for the new fields
            HMBTextField(
                controller: _nameController,
                labelText: 'Name',
                required: true,
                keyboardType: TextInputType.name),
            HMBTextField(
                controller: _descriptionController, labelText: 'Description'),
            if (widget.checkListType == null)
              HMBDroplist<CheckListType>(
                  initialItem: () async =>
                      checklist?.listType ?? CheckListType.global,
                  title: 'Checklist Type',
                  items: (filter) async => Strings.isEmpty(filter)
                      ? CheckListType.values
                      : CheckListType.values
                          .where((item) => item.name.contains(filter!))
                          .toList(),
                  onChanged: (item) => June.getState(CheckListTypeStatus.new)
                      .checkListType = item!,
                  format: (taskStatus) => taskStatus.name),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    HBMCrudCheckListItem<CheckList>(
                      parent: Parent(checklist),
                      daoJoin: JoinAdaptorCheckListCheckListItem(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  @override
  Future<CheckList> forUpdate(CheckList checklist) async => CheckList.forUpdate(
      entity: checklist,
      name: _nameController.text,
      description: _descriptionController.text,
      listType: June.getState(CheckListTypeStatus.new).checkListType);

  @override
  Future<CheckList> forInsert() async => CheckList.forInsert(
      name: _nameController.text,
      description: _descriptionController.text,
      listType: June.getState(CheckListTypeStatus.new).checkListType);

  @override
  void refresh() {
    setState(() {});
  }
}

class CheckListTypeStatus {
  CheckListTypeStatus();

  CheckListType checkListType = CheckListType.owned;
}
