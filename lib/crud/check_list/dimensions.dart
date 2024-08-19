import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:june/june.dart';

import '../../dao/dao_check_list_item_type.dart';
import '../../entity/check_list_item.dart';
import '../../util/measurement_type.dart';
import '../../util/units.dart';
import '../../widgets/hmb_droplist.dart';
import '../../widgets/hmb_empty.dart';
import '../../widgets/hmb_text_field.dart';
import 'checklist_item_edit_screen.dart';

class DimensionWidget extends StatefulWidget {
  const DimensionWidget(
      {required this.checkListItem,
      required this.dimension1Controller,
      required this.dimension2Controller,
      required this.dimension3Controller,
      super.key});

  final CheckListItem? checkListItem;

  final TextEditingController dimension1Controller;

  final TextEditingController dimension2Controller;

  final TextEditingController dimension3Controller;

  @override
  State<DimensionWidget> createState() => _DimensionWidgetState();
}

class _DimensionWidgetState extends State<DimensionWidget> {
  @override
  void dispose() {
    super.dispose();
  }

  // Define the specific item types that should trigger the dimension
  //and units dropdown
  final List<String> _itemTypesWithDimensions = [
    'Materials - buy',
    'Materials - stock'
  ];

  @override
  Widget build(BuildContext context) => JuneBuilder<SelectedCheckListItemType>(
      SelectedCheckListItemType.new,
      builder: (selectedItemType) => FutureBuilderEx(
          // ignore: discarded_futures
          future: DaoCheckListItemType().getById(selectedItemType.selected),
          builder: (context, itemType) {
            if (!_itemTypesWithDimensions.contains(itemType?.name ?? '')) {
              return const HMBEmpty();
            } else {
              return Column(children: [
                HMBDroplist<MeasurementType>(
                  title: 'Measurement Type',
                  initialItem: () async =>
                      June.getState(SelectedDimensionType.new).selected,
                  format: (type) => type.name,
                  items: (filter) async => MeasurementType.list,
                  onChanged: (value) async {
                    if (June.getState(SelectedDimensionType.new).selected !=
                        value) {
                      June.getState(SelectedUnits.new).selected =
                          await getDefaultUnitForMeasurementType(value);
                    }
                    setState(() {
                      June.getState(SelectedDimensionType.new).selected = value;
                      June.getState(SelectedUnits.new).setState();
                    });
                  },
                ),

                /// Units
                HMBDroplist<Units>(
                    title: 'Units',
                    initialItem: () async =>
                        June.getState(SelectedUnits.new).selectedOrDefault,
                    format: (unit) => unit.name,
                    items: (filter) async => getUnitsForMeasurementType(
                        June.getState(SelectedDimensionType.new)
                            .selectedOrDefault),
                    onChanged: (value) {
                      setState(() {
                        June.getState(SelectedUnits.new).selected = value;
                      });
                    }),
                HMBTextField(
                  controller: widget.dimension1Controller,
                  labelText: June.getState(SelectedDimensionType.new)
                      .selectedOrDefault
                      .labels[0],
                  keyboardType: TextInputType.number,
                ),
                if ((June.getState(SelectedUnits.new).selected?.dimensions ??
                        2) >
                    1)
                  HMBTextField(
                    controller: widget.dimension2Controller,
                    labelText: June.getState(SelectedDimensionType.new)
                        .selectedOrDefault
                        .labels[1],
                    keyboardType: TextInputType.number,
                  ),
                if ((June.getState(SelectedUnits.new).selected?.dimensions ??
                        3) >
                    2)
                  HMBTextField(
                    controller: widget.dimension3Controller,
                    labelText: June.getState(SelectedDimensionType.new)
                        .selectedOrDefault
                        .labels[2],
                    keyboardType: TextInputType.number,
                  ),
              ]);
            }
          }));
}

/// The selected [MeasurementType]
class SelectedDimensionType extends JuneState {
  MeasurementType? _selected;

  set selected(MeasurementType? value) {
    _selected = value;

    setState();
  }

  MeasurementType? get selected => _selected;

  MeasurementType get selectedOrDefault => _selected ?? length;
}

/// The selected Units
class SelectedUnits extends JuneState {
  Units? _selected;

  set selected(Units? value) {
    _selected = value;

    setState();
  }

  Units? get selected => _selected;
  Units get selectedOrDefault => _selected ?? const Units('mm', 1);
}
