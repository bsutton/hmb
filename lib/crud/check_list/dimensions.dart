import 'dart:async';

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:june/june.dart';

import '../../dao/dao_check_list_item_type.dart';
import '../../dao/dao_system.dart';
import '../../entity/check_list_item.dart';
import '../../entity/check_list_item_type.dart';
import '../../util/measurement_type.dart';
import '../../util/units.dart';
import '../../widgets/hmb_droplist.dart';
import '../../widgets/hmb_empty.dart';
import '../../widgets/hmb_text.dart';
import '../../widgets/hmb_text_field.dart';
import 'edit_checklist_item_screen.dart';

class DimensionWidget extends StatefulWidget {
  const DimensionWidget({
    required this.checkListItem,
    required this.dimension1Controller,
    required this.dimension2Controller,
    required this.dimension3Controller,
    super.key,
  });

  final CheckListItem? checkListItem;

  final TextEditingController dimension1Controller;

  final TextEditingController dimension2Controller;

  final TextEditingController dimension3Controller;

  @override
  State<DimensionWidget> createState() => _DimensionWidgetState();
}

class _DimensionWidgetState extends State<DimensionWidget> {
  // Define the specific item types that should trigger
  // the dimension and units dropdown
  final List<String> _itemTypesWithDimensions = [
    'Materials - buy',
    'Materials - stock',
  ];

  @override
  void initState() {
    super.initState();

    // Initialize the selected measurement type and units using JuneState
    final selectedMeasurementTypeState =
        June.getState(SelectedMeasurementType.new)
          ..selected =
              widget.checkListItem?.measurementType ?? MeasurementType.length;

    unawaited(getDefaultUnitForMeasurementType(
            selectedMeasurementTypeState.selectedOrDefault)
        .then((defaultUnits) {
      June.getState(SelectedUnits.new).selected =
          widget.checkListItem?.units ?? defaultUnits;
    }));
  }

  @override
  Widget build(BuildContext context) => JuneBuilder<SelectedCheckListItemType>(
        SelectedCheckListItemType.new,
        builder: (selectedItemTypeState) => FutureBuilderEx<CheckListItemType?>(
          future:
              // ignore: discarded_futures
              DaoCheckListItemType().getById(selectedItemTypeState.selected),
          builder: (context, itemType) {
            if (!_itemTypesWithDimensions.contains(itemType?.name ?? '')) {
              return const HMBEmpty();
            } else {
              final selectedUnitsState = June.getState(SelectedUnits.new);
              final selectedMeasurementTypeState =
                  June.getState(SelectedMeasurementType.new);

              final selectedUnit = selectedUnitsState.selectedOrDefault;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HMBDroplist<MeasurementType>(
                    title: 'Measurement Type',
                    selectedItem: () async =>
                        selectedMeasurementTypeState.selected,
                    format: (type) => type.name,
                    items: (filter) async => MeasurementType.list,
                    onChanged: (value) async {
                      if (selectedMeasurementTypeState.selected != value) {
                        selectedUnitsState.selected =
                            await getDefaultUnitForMeasurementType(
                                value ?? MeasurementType.length);
                      }
                      setState(() {
                        selectedMeasurementTypeState.selected =
                            value ?? MeasurementType.length;
                        selectedUnitsState.setState();
                      });
                    },
                  ),

                  /// Units
                  HMBDroplist<Units>(
                    title: 'Units',
                    selectedItem: () async => selectedUnit,
                    format: (unit) => unit.name,
                    items: (filter) async => getUnitsForMeasurementType(
                        selectedMeasurementTypeState.selectedOrDefault),
                    onChanged: (value) {
                      setState(() {
                        selectedUnitsState.selected = value ?? selectedUnit;
                      });
                    },
                  ),

                  // Display the total measurement
                  JuneBuilder<MeasuremenTotal>(
                    MeasuremenTotal.new,
                    builder: (context) {
                      final totalMeasurement = selectedUnit.calc([
                        widget.dimension1Controller.text,
                        widget.dimension2Controller.text,
                        widget.dimension3Controller.text,
                      ]);

                      return HMBText(
                        '''
Measurements: Total: $totalMeasurement ${selectedUnit.name}''',
                      );
                    },
                  ),

                  // Dimension fields
                  HMBTextField(
                    controller: widget.dimension1Controller,
                    labelText:
                        '${selectedUnit.labels[0]} (${selectedUnit.measure})',
                    keyboardType: TextInputType.number,
                    onChanged: (_) =>
                        June.getState(MeasuremenTotal.new).setState(),
                  ),
                  if (selectedUnit.dimensions > 1)
                    HMBTextField(
                      controller: widget.dimension2Controller,
                      labelText:
                          '${selectedUnit.labels[1]} (${selectedUnit.measure})',
                      keyboardType: TextInputType.number,
                      onChanged: (_) =>
                          June.getState(MeasuremenTotal.new).setState(),
                    ),
                  if (selectedUnit.dimensions > 2)
                    HMBTextField(
                      controller: widget.dimension3Controller,
                      labelText:
                          '${selectedUnit.labels[2]} (${selectedUnit.measure})',
                      keyboardType: TextInputType.number,
                      onChanged: (_) =>
                          June.getState(MeasuremenTotal.new).setState(),
                    ),
                ],
              );
            }
          },
        ),
      );
}

/// The selected [MeasurementType]
class SelectedMeasurementType extends JuneState {
  MeasurementType? _selected;

  set selected(MeasurementType? value) {
    _selected = value;
    setState();
  }

  MeasurementType? get selected => _selected;

  MeasurementType get selectedOrDefault => _selected ?? MeasurementType.length;
}

/// The selected Units
class SelectedUnits extends JuneState {
  Units? _selected;

  set selected(Units? value) {
    _selected = value;
    setState();
  }

  Units? get selected => _selected;
  Units get selectedOrDefault => _selected ?? Units.mm;
}

class MeasuremenTotal extends JuneState {}

MeasurementType getDefaultMeasurementType() => MeasurementType.length;

Future<Units> getDefaultUnitForMeasurementType(
    MeasurementType measurementType) async {
  final system = await DaoSystem().get();
  if ((system?.preferredUnitSystem ?? PreferredUnitSystem.metric) ==
      PreferredUnitSystem.metric) {
    return measurementType.defaultMetric;
  } else {
    return measurementType.defaultImperial;
  }
}

Future<List<Units>> getUnitsForMeasurementType(
    MeasurementType measurementType) async {
  final system = await DaoSystem().get();
  if ((system?.preferredUnitSystem ?? PreferredUnitSystem.metric) ==
      PreferredUnitSystem.metric) {
    return measurementType.metric;
  } else {
    return measurementType.imperial;
  }
}
