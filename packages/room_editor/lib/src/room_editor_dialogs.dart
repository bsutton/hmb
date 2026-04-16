import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'room_canvas_geometry.dart';
import 'room_canvas_models.dart';
import 'room_constraint_solver.dart';

Future<int?> showRoomEditorLengthDialog({
  required BuildContext context,
  required RoomEditorUnitSystem unitSystem,
  required int initialValue,
}) => showDialog<int>(
  context: context,
  builder: (_) =>
      _LengthDialog(unitSystem: unitSystem, initialValue: initialValue),
);

Future<int?> showRoomEditorAngleDialog({
  required BuildContext context,
  required int initialValue,
}) => showDialog<int>(
  context: context,
  builder: (_) => _AngleDialog(initialValue: initialValue),
);

Future<RoomEditorOpeningDraft?> showRoomEditorOpeningDialog({
  required BuildContext context,
  required RoomEditorUnitSystem unitSystem,
  required RoomEditorOpeningType type,
  RoomEditorOpeningDraft? initialOpening,
  String? title,
  String? confirmLabel,
}) => showDialog<RoomEditorOpeningDraft>(
  context: context,
  builder: (_) => _OpeningDialog(
    unitSystem: unitSystem,
    type: type,
    initialOpening: initialOpening,
    title: title,
    confirmLabel: confirmLabel,
  ),
);

class _LengthDialog extends StatefulWidget {
  final RoomEditorUnitSystem unitSystem;
  final int initialValue;

  const _LengthDialog({required this.unitSystem, required this.initialValue});

  @override
  State<_LengthDialog> createState() => _LengthDialogState();
}

class _LengthDialogState extends State<_LengthDialog> {
  late final TextEditingController _metricController;
  late final TextEditingController _feetController;
  late final TextEditingController _inchesController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _metricController = TextEditingController(
      text: widget.unitSystem == RoomEditorUnitSystem.metric
          ? RoomCanvasGeometry.formatDisplayLength(
              widget.initialValue,
              widget.unitSystem,
            ).replaceFirst(RegExp(r'\s+mm$'), '')
          : '',
    );
    final totalInches =
        widget.initialValue / RoomCanvasGeometry.imperialUnitsPerInch;
    final feet = totalInches ~/ RoomCanvasGeometry.inchesPerFoot;
    final inches = totalInches - feet * RoomCanvasGeometry.inchesPerFoot;
    _feetController = TextEditingController(
      text: widget.unitSystem == RoomEditorUnitSystem.imperial
          ? feet.toString()
          : '',
    );
    _inchesController = TextEditingController(
      text: widget.unitSystem == RoomEditorUnitSystem.imperial
          ? _formatInches(inches)
          : '',
    );
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _focusNode.requestFocus();
      final controller = widget.unitSystem == RoomEditorUnitSystem.metric
          ? _metricController
          : _feetController;
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: controller.text.length,
      );
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _metricController.dispose();
    _feetController.dispose();
    _inchesController.dispose();
    super.dispose();
  }

  int? _parseValue() {
    if (widget.unitSystem == RoomEditorUnitSystem.metric) {
      return RoomCanvasGeometry.parseDisplayLength(
        _metricController.text,
        widget.unitSystem,
      );
    }

    final feet = int.tryParse(_feetController.text.trim()) ?? 0;
    final inches = double.tryParse(_inchesController.text.trim()) ?? 0;
    if (feet == 0 && inches == 0) {
      return null;
    }
    final totalInches = feet * RoomCanvasGeometry.inchesPerFoot + inches;
    return (totalInches * RoomCanvasGeometry.imperialUnitsPerInch).round();
  }

  String _formatInches(double value) {
    final rounded = value.toStringAsFixed(3);
    return rounded.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  Widget _buildMetricField() => TextField(
    controller: _metricController,
    focusNode: _focusNode,
    autofocus: true,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
    decoration: const InputDecoration(labelText: 'Length (mm)'),
  );

  Widget _buildImperialFields(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _feetController,
              focusNode: _focusNode,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Feet'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _inchesController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              decoration: const InputDecoration(labelText: 'Inches'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Text(
        'Enter feet and inches separately. Decimal inches are supported.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Set Length'),
    content: widget.unitSystem == RoomEditorUnitSystem.metric
        ? _buildMetricField()
        : _buildImperialFields(context),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () {
          final value = _parseValue();
          if (value == null) {
            return;
          }
          Navigator.of(context).pop(value);
        },
        child: const Text('Save'),
      ),
    ],
  );
}

class _AngleDialog extends StatefulWidget {
  final int initialValue;

  const _AngleDialog({required this.initialValue});

  @override
  State<_AngleDialog> createState() => _AngleDialogState();
}

class _AngleDialogState extends State<_AngleDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: RoomEditorConstraintSolver.angleValueToDegrees(
        widget.initialValue,
      ).toStringAsFixed(1),
    );
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _focusNode.requestFocus();
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Set Angle'),
    content: TextField(
      controller: _controller,
      focusNode: _focusNode,
      autofocus: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(labelText: 'Angle (degrees)'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () {
          final value = double.tryParse(_controller.text.trim());
          if (value == null || value <= 0 || value >= 180) {
            return;
          }
          Navigator.of(
            context,
          ).pop(RoomEditorConstraintSolver.degreesToAngleValue(value));
        },
        child: const Text('Save'),
      ),
    ],
  );
}

class _OpeningDialog extends StatefulWidget {
  final RoomEditorUnitSystem unitSystem;
  final RoomEditorOpeningType type;
  final RoomEditorOpeningDraft? initialOpening;
  final String title;
  final String confirmLabel;

  const _OpeningDialog({
    required this.unitSystem,
    required this.type,
    this.initialOpening,
    String? title,
    String? confirmLabel,
  }) : title =
           title ??
           (type == RoomEditorOpeningType.door ? 'Add Door' : 'Add Window'),
       confirmLabel = confirmLabel ?? 'Add';

  @override
  State<_OpeningDialog> createState() => _OpeningDialogState();
}

class _OpeningDialogState extends State<_OpeningDialog> {
  final _width = TextEditingController();
  final _height = TextEditingController();
  final _sill = TextEditingController();

  @override
  void initState() {
    super.initState();
    final initialOpening = widget.initialOpening;
    if (initialOpening != null) {
      _width.text = RoomCanvasGeometry.formatDisplayLength(
        initialOpening.width,
        widget.unitSystem,
      ).replaceFirst(RegExp(r'\s+[A-Za-z/"]+$'), '');
      _height.text = RoomCanvasGeometry.formatDisplayLength(
        initialOpening.height,
        widget.unitSystem,
      ).replaceFirst(RegExp(r'\s+[A-Za-z/"]+$'), '');
      _sill.text = RoomCanvasGeometry.formatDisplayLength(
        initialOpening.sillHeight,
        widget.unitSystem,
      ).replaceFirst(RegExp(r'\s+[A-Za-z/"]+$'), '');
    } else if (widget.unitSystem == RoomEditorUnitSystem.metric) {
      _width.text = widget.type == RoomEditorOpeningType.door ? '820' : '1200';
      _height.text = widget.type == RoomEditorOpeningType.door
          ? '2040'
          : '1200';
      _sill.text = widget.type == RoomEditorOpeningType.window ? '900' : '0';
    } else {
      _width.text = widget.type == RoomEditorOpeningType.door
          ? '2\' 8"'
          : '4\' 0"';
      _height.text = widget.type == RoomEditorOpeningType.door
          ? '6\' 8"'
          : '4\' 0"';
      _sill.text = widget.type == RoomEditorOpeningType.window
          ? '3\' 0"'
          : '0\' 0"';
    }
  }

  @override
  void dispose() {
    _width.dispose();
    _height.dispose();
    _sill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _width,
          keyboardType: TextInputType.text,
          decoration: InputDecoration(
            labelText:
                'Width (${RoomCanvasGeometry.unitLabel(widget.unitSystem)})',
          ),
        ),
        TextField(
          controller: _height,
          keyboardType: TextInputType.text,
          decoration: InputDecoration(
            labelText:
                'Height (${RoomCanvasGeometry.unitLabel(widget.unitSystem)})',
          ),
        ),
        if (widget.type == RoomEditorOpeningType.window)
          TextField(
            controller: _sill,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              labelText: '''
Sill Height (${RoomCanvasGeometry.unitLabel(widget.unitSystem)})''',
            ),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () {
          final width = RoomCanvasGeometry.parseDisplayLength(
            _width.text,
            widget.unitSystem,
          );
          final height = RoomCanvasGeometry.parseDisplayLength(
            _height.text,
            widget.unitSystem,
          );
          final sill =
              RoomCanvasGeometry.parseDisplayLength(
                _sill.text,
                widget.unitSystem,
              ) ??
              0;
          if (width == null || height == null) {
            return;
          }
          Navigator.of(context).pop(
            RoomEditorOpeningDraft(
              type: widget.type,
              width: width,
              height: height,
              sillHeight: sill,
            ),
          );
        },
        child: Text(widget.confirmLabel),
      ),
    ],
  );
}
