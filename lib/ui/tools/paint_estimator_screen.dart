import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../dao/dao.g.dart';
import '../../dao/dao_paint_estimate.dart';
import '../../entity/entity.g.dart';
import '../../util/dart/paint_estimate.dart';
import '../widgets/fields/hmb_text_field.dart';
import '../widgets/layout/layout.g.dart';
import '../widgets/select/hmb_droplist.dart';
import '../widgets/widgets.g.dart';

class PaintEstimatorScreen extends StatefulWidget {
  final PlasterProject? project;
  const PaintEstimatorScreen({super.key, this.project});

  @override
  State<PaintEstimatorScreen> createState() => _PaintEstimatorScreenState();
}

class _PaintEstimatorScreenState extends DeferredState<PaintEstimatorScreen> {
  final _form = GlobalKey<FormState>();
  final _prepRate = TextEditingController();
  final _finishRate = TextEditingController();
  final _windowRate = TextEditingController();
  final _colourRate = TextEditingController();
  final _coats = TextEditingController();
  final _colours = TextEditingController();
  PlasterProject? _project;
  List<PlasterRoom> _rooms = [];
  PlasterRoom? _room;
  List<PlasterRoomLine> _lines = [];
  List<PlasterRoomOpening> _openings = [];
  var _settings = PaintSettings();
  PaintEstimate? _result;

  @override
  Future<void> asyncInitState() async {
    if (widget.project != null) {
      await _selectProject(widget.project);
    }
  }

  Future<void> _selectProject(PlasterProject? project) async {
    final rooms = project == null
        ? <PlasterRoom>[]
        : await BlockingUI().runAndWait(
            () => DaoPlasterRoom().getByProject(project.id),
          );
    if (mounted) {
      setState(() {
        _project = project;
        _rooms = rooms;
        _room = null;
        _result = null;
      });
    }
  }

  Future<void> _selectRoom(PlasterRoom? room) async {
    if (room == null) {
      setState(() {
        _room = null;
        _result = null;
      });
      return;
    }
    await BlockingUI().runAndWait(() async {
      _lines = await DaoPlasterRoomLine().getByRoom(room.id);
      _openings = await DaoPlasterRoomOpening().getByLineIds(
        _lines.map((line) => line.id).toList(),
      );
      _settings = await DaoPaintEstimate().get(room.id);
    });
    if (mounted) {
      setState(() {
        _room = room;
        _result = null;
        _prepRate.text = _settings.preparationRates[_settings.preparation]
            .toString();
        _finishRate.text = _settings.finishRates[_settings.finish].toString();
        _windowRate.text = _settings.windowHours.toString();
        _colourRate.text = _settings.extraColourHours.toString();
        _coats.text = _settings.coats.toString();
        _colours.text = _settings.colours.toString();
      });
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _prepRate,
      _finishRate,
      _windowRate,
      _colourRate,
      _coats,
      _colours,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _number(
    TextEditingController controller,
    String label, {
    bool count = false,
  }) => HMBTextField(
    controller: controller,
    labelText: label,
    required: true,
    keyboardType: TextInputType.numberWithOptions(decimal: !count),
    onChanged: (_) => setState(() => _result = null),
    validator: (value) {
      final number = double.tryParse(value ?? '');
      if (number == null ||
          !number.isFinite ||
          number < 0 ||
          (count && (int.tryParse(value!.trim()) == null || number < 1))) {
        return count
            ? 'Enter a positive whole number'
            : 'Enter a non-negative rate';
      }
      return null;
    },
  );

  Future<void> _calculate() async {
    if (!_form.currentState!.validate() || _room == null) {
      return;
    }
    _settings
      ..coats = int.parse(_coats.text.trim())
      ..colours = int.parse(_colours.text.trim())
      ..windowHours = double.parse(_windowRate.text)
      ..extraColourHours = double.parse(_colourRate.text);
    _settings.preparationRates[_settings.preparation] = double.parse(
      _prepRate.text,
    );
    _settings.finishRates[_settings.finish] = double.parse(_finishRate.text);
    try {
      final result = PaintEstimate.fromRoom(
        _room!,
        _lines,
        _openings,
        _settings,
      );
      await BlockingUI().runAndWait(
        () => DaoPaintEstimate().save(_room!.id, _settings),
      );
      if (mounted) {
        setState(() => _result = result);
      }
    } on FormatException catch (error) {
      HMBToast.error(error.message);
    }
  }

  @override
  Widget build(BuildContext context) => HMBFullPageChildScreen(
    title: 'Paint estimator',
    maxContentWidth: 800,
    child: DeferredBuilder(
      this,
      waitingBuilder: (_) => const SizedBox.shrink(),
      errorBuilder: (_, _) => const Text('Could not load room layouts.'),
      builder: (context) => Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Uses existing room layouts. Edit dimensions and openings '
              'in the room drawing editor. Painting choices are independent of '
              'plasterboard selections.',
            ),
            HMBDroplist<PlasterProject>(
              title: 'Room project',
              selectedItem: () async => _project,
              items: (filter) => DaoPlasterProject().getByFilter(filter),
              format: (project) => project.name,
              onChanged: _selectProject,
            ),
            HMBDroplist<PlasterRoom>(
              key: ValueKey(_project?.id),
              title: 'Room',
              selectedItem: () async => _room,
              items: (filter) async => _rooms
                  .where(
                    (room) => room.name.toLowerCase().contains(
                      (filter ?? '').toLowerCase(),
                    ),
                  )
                  .toList(),
              format: (room) => room.name,
              onChanged: _selectRoom,
            ),
            if (_project != null && _rooms.isEmpty)
              const Text(
                'This project has no rooms. Add one in the room layout editor.',
              ),
            if (_room != null) ...[
              const SizedBox(height: 16),
              Text(
                'Paint surfaces',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (var index = 0; index < _lines.length; index++)
                HMBToggle(
                  key: ValueKey('paint-wall-${_lines[index].id}'),
                  label: 'Wall ${index + 1}',
                  hint: 'Include this wall in painting',
                  initialValue: !_settings.excludedWalls.contains(
                    _lines[index].id,
                  ),
                  onToggled: (value) => setState(() {
                    if (value) {
                      _settings.excludedWalls.remove(_lines[index].id);
                    } else {
                      _settings.excludedWalls.add(_lines[index].id);
                    }
                    _result = null;
                  }),
                ),
              HMBToggle(
                key: ValueKey('paint-ceiling-${_room!.id}'),
                label: 'Paint ceiling',
                hint: 'Use the drawn room footprint',
                initialValue: _settings.ceiling,
                onToggled: (value) => setState(() {
                  _settings.ceiling = value;
                  _result = null;
                }),
              ),
              const Text(
                'Rates below are editable starter assumptions, not industry '
                'benchmarks. Calibrate them against your recorded job times.',
              ),
              HMBDroplist<PaintPreparation>(
                key: ValueKey('prep-${_room!.id}'),
                title: 'Preparation grade',
                selectedItem: () async => _settings.preparation,
                items: (_) async => PaintPreparation.values,
                format: (grade) => grade.label,
                onChanged: (grade) => setState(() {
                  final previous = double.tryParse(_prepRate.text);
                  if (previous != null && previous.isFinite && previous >= 0) {
                    _settings.preparationRates[_settings.preparation] =
                        previous;
                  }
                  _settings.preparation = grade ?? _settings.preparation;
                  _prepRate.text = _settings
                      .preparationRates[_settings.preparation]
                      .toString();
                  _result = null;
                }),
              ),
              _number(_prepRate, 'Preparation hours per m² (all prep steps)'),
              HMBDroplist<PaintFinish>(
                key: ValueKey('finish-${_room!.id}'),
                title: 'Finish',
                selectedItem: () async => _settings.finish,
                items: (_) async => PaintFinish.values,
                format: (finish) => finish.label,
                onChanged: (finish) => setState(() {
                  final previous = double.tryParse(_finishRate.text);
                  if (previous != null && previous.isFinite && previous >= 0) {
                    _settings.finishRates[_settings.finish] = previous;
                  }
                  _settings.finish = finish ?? _settings.finish;
                  _finishRate.text = _settings.finishRates[_settings.finish]
                      .toString();
                  _result = null;
                }),
              ),
              _number(_finishRate, 'Finish hours per m² per coat'),
              _number(_coats, 'Coats', count: true),
              _number(_colours, 'Colours', count: true),
              _number(_colourRate, 'Setup hours per extra colour'),
              HMBToggle(
                key: ValueKey('complex-${_room!.id}'),
                label: 'Complex windows / divided panes',
                hint: 'Use a larger starter window allowance',
                initialValue: _settings.complexWindows,
                onToggled: (value) => setState(() {
                  _settings.complexWindows = value;
                  _windowRate.text = value ? '1.5' : '0.5';
                  _result = null;
                }),
              ),
              _number(_windowRate, 'Hours per window (all coats)'),
              HMBButtonPrimary(
                label: 'Save and calculate',
                hint: 'Save room assumptions and calculate labour hours',
                onPressed: _calculate,
              ),
              if (_result != null) ...[
                Text(_result!.summary),
                HMBButtonSecondary(
                  label: 'Copy estimate',
                  hint: 'Copy the result and assumptions',
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(
                        text: '${_room!.name}\n${_result!.summary}',
                      ),
                    );
                    HMBToast.info('Estimate copied');
                  },
                ),
              ],
            ],
          ],
        ),
      ),
    ),
  );
}
