/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.
*/

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';

import '../../../dao/dao_custom_label_layout.dart';
import '../../../entity/custom_label_layout.dart';
import '../../../util/dart/measurement_type.dart';
import '../../crud/base_full_screen/edit_entity_screen.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../../widgets/hmb_toast.dart';
import '../../widgets/layout/layout.g.dart';
import 'label_layout.dart';

class CustomLabelLayoutEditScreen extends StatefulWidget {
  final CustomLabelLayout? layout;
  final PreferredUnitSystem unitSystem;
  final bool duplicate;

  const CustomLabelLayoutEditScreen({
    required this.unitSystem,
    this.layout,
    this.duplicate = false,
    super.key,
  });

  @override
  State<CustomLabelLayoutEditScreen> createState() =>
      _CustomLabelLayoutEditScreenState();
}

class _CustomLabelLayoutEditScreenState
    extends State<CustomLabelLayoutEditScreen>
    implements EntityState<CustomLabelLayout> {
  late final TextEditingController _nameController;
  late final TextEditingController _pageWidthController;
  late final TextEditingController _pageHeightController;
  late final TextEditingController _columnsController;
  late final TextEditingController _rowsController;
  late final TextEditingController _labelWidthController;
  late final TextEditingController _labelHeightController;
  late final TextEditingController _marginLeftController;
  late final TextEditingController _marginTopController;
  late final TextEditingController _gapXController;
  late final TextEditingController _gapYController;

  @override
  CustomLabelLayout? currentEntity;

  double get _unitFactor => widget.unitSystem == PreferredUnitSystem.metric
      ? PdfPageFormat.mm
      : PdfPageFormat.inch;

  String get _unitLabel =>
      widget.unitSystem == PreferredUnitSystem.metric ? 'mm' : 'in';

  @override
  void initState() {
    super.initState();
    currentEntity = widget.duplicate ? null : widget.layout;
    final custom = widget.layout;
    final base = custom == null
        ? LabelLayout.forUnitSystem(widget.unitSystem).first
        : LabelLayout.fromCustom(custom);

    _nameController = TextEditingController(
      text: custom == null
          ? ''
          : widget.duplicate
          ? '${custom.name} copy'
          : custom.name,
    );
    _pageWidthController = TextEditingController(
      text: _display(base.pageFormat.width),
    );
    _pageHeightController = TextEditingController(
      text: _display(base.pageFormat.height),
    );
    _columnsController = TextEditingController(text: '${base.columns}');
    _rowsController = TextEditingController(text: '${base.rows}');
    _labelWidthController = TextEditingController(
      text: _display(base.labelWidth),
    );
    _labelHeightController = TextEditingController(
      text: _display(base.labelHeight),
    );
    _marginLeftController = TextEditingController(
      text: _display(base.marginLeft),
    );
    _marginTopController = TextEditingController(
      text: _display(base.marginTop),
    );
    _gapXController = TextEditingController(
      text: _display(base.columnPitch - base.labelWidth),
    );
    _gapYController = TextEditingController(
      text: _display(base.rowPitch - base.labelHeight),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pageWidthController.dispose();
    _pageHeightController.dispose();
    _columnsController.dispose();
    _rowsController.dispose();
    _labelWidthController.dispose();
    _labelHeightController.dispose();
    _marginLeftController.dispose();
    _marginTopController.dispose();
    _gapXController.dispose();
    _gapYController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => EntityEditScreen<CustomLabelLayout>(
    entityName: 'Custom Label',
    dao: DaoCustomLabelLayout(),
    entityState: this,
    crossValidator: _fitsPage,
    editor: (layout, {required isNew}) => HMBColumn(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HMBTextField(
          controller: _nameController,
          labelText: 'Name',
          required: true,
        ),
        HMBRow(
          children: [
            Expanded(child: _number(_pageWidthController, 'Page width')),
            Expanded(child: _number(_pageHeightController, 'Page height')),
          ],
        ),
        HMBRow(
          children: [
            Expanded(child: _integer(_columnsController, 'Across')),
            Expanded(child: _integer(_rowsController, 'Down')),
          ],
        ),
        HMBRow(
          children: [
            Expanded(child: _number(_labelWidthController, 'Label width')),
            Expanded(child: _number(_labelHeightController, 'Label height')),
          ],
        ),
        HMBRow(
          children: [
            Expanded(
              child: _number(
                _marginLeftController,
                'Left margin',
                allowZero: true,
              ),
            ),
            Expanded(
              child: _number(
                _marginTopController,
                'Top margin',
                allowZero: true,
              ),
            ),
          ],
        ),
        HMBRow(
          children: [
            Expanded(
              child: _number(_gapXController, 'Gap across', allowZero: true),
            ),
            Expanded(
              child: _number(_gapYController, 'Gap down', allowZero: true),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _number(
    TextEditingController controller,
    String label, {
    bool allowZero = false,
  }) => HMBTextField(
    controller: controller,
    labelText: '$label ($_unitLabel)',
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9.]'))],
    validator: (value) {
      final parsed = double.tryParse(value ?? '');
      final invalid = parsed == null || (allowZero ? parsed < 0 : parsed <= 0);
      return invalid ? 'Enter a value' : null;
    },
  );

  Widget _integer(TextEditingController controller, String label) =>
      HMBTextField(
        controller: controller,
        labelText: label,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        validator: (value) {
          final parsed = int.tryParse(value ?? '');
          return parsed == null || parsed <= 0 ? 'Enter a count' : null;
        },
      );

  @override
  Future<CustomLabelLayout> forInsert() async => CustomLabelLayout.forInsert(
    name: _nameController.text.trim(),
    unitSystem: widget.unitSystem,
    pageWidth: _points(_pageWidthController),
    pageHeight: _points(_pageHeightController),
    columns: int.parse(_columnsController.text),
    rows: int.parse(_rowsController.text),
    labelWidth: _points(_labelWidthController),
    labelHeight: _points(_labelHeightController),
    marginLeft: _points(_marginLeftController),
    marginTop: _points(_marginTopController),
    gapX: _points(_gapXController),
    gapY: _points(_gapYController),
  );

  @override
  Future<CustomLabelLayout> forUpdate(CustomLabelLayout entity) async =>
      entity.copyWith(
        name: _nameController.text.trim(),
        pageWidth: _points(_pageWidthController),
        pageHeight: _points(_pageHeightController),
        columns: int.parse(_columnsController.text),
        rows: int.parse(_rowsController.text),
        labelWidth: _points(_labelWidthController),
        labelHeight: _points(_labelHeightController),
        marginLeft: _points(_marginLeftController),
        marginTop: _points(_marginTopController),
        gapX: _points(_gapXController),
        gapY: _points(_gapYController),
      );

  @override
  Future<void> postSave(CustomLabelLayout entity) async {
    setState(() {});
  }

  Future<bool> _fitsPage() async {
    final pageWidth = _points(_pageWidthController);
    final pageHeight = _points(_pageHeightController);
    final columns = int.parse(_columnsController.text);
    final rows = int.parse(_rowsController.text);
    final labelWidth = _points(_labelWidthController);
    final labelHeight = _points(_labelHeightController);
    final marginLeft = _points(_marginLeftController);
    final marginTop = _points(_marginTopController);
    final gapX = _points(_gapXController);
    final gapY = _points(_gapYController);
    final usedWidth = marginLeft + columns * labelWidth + (columns - 1) * gapX;
    final usedHeight = marginTop + rows * labelHeight + (rows - 1) * gapY;
    if (usedWidth <= pageWidth && usedHeight <= pageHeight) {
      return true;
    }
    HMBToast.error('Labels do not fit on the page.');
    return false;
  }

  double _points(TextEditingController controller) =>
      double.parse(controller.text) * _unitFactor;

  String _display(double points) {
    final value = points / _unitFactor;
    return value.toStringAsFixed(value >= 10 ? 1 : 2);
  }
}
