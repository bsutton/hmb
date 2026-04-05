/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.
*/

import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../../main.dart';
import '../../../util/dart/app_settings.dart';
import '../../../util/dart/log.dart';
import '../../../util/dart/measurement_type.dart';
import '../../../util/dart/plaster_geometry.dart';
import '../../../util/dart/plaster_sheet_direction.dart';
import 'package:room_editor/room_editor.dart';
import '../../crud/base_nested/list_nested_screen.dart';
import '../../dialog/email_dialog.dart';
import '../../nav/nav.g.dart';
import '../../widgets/blocking_ui.dart';
import '../../widgets/color_ex.dart';
import '../../widgets/hmb_child_crud_card.dart';
import '../../widgets/media/pdf_preview.dart';
import '../../widgets/select/hmb_select_job.dart';
import '../../widgets/select/hmb_select_supplier.dart';
import '../../widgets/select/hmb_select_task.dart';
import 'plaster_material_size_list_screen.dart';
import 'plaster_project_pdf.dart';
import 'plaster_room_list_screen.dart';

class PlasterProjectScreen extends StatefulWidget {
  final PlasterProject? project;
  final int? editorOnlyRoomId;

  const PlasterProjectScreen({
    required this.project,
    this.editorOnlyRoomId,
    super.key,
  });

  @override
  State<PlasterProjectScreen> createState() => _PlasterProjectScreenState();
}

class _PlasterProjectScreenState extends DeferredState<PlasterProjectScreen>
    with RouteAware {
  final _nameController = TextEditingController();
  final _roomNameController = TextEditingController();
  final _wasteController = TextEditingController();
  final _ceilingHeightController = TextEditingController();
  final _wallStudSpacingController = TextEditingController();
  final _wallStudOffsetController = TextEditingController();
  final _wallFixingFaceWidthController = TextEditingController();
  final _ceilingFramingSpacingController = TextEditingController();
  final _ceilingFramingOffsetController = TextEditingController();
  final _ceilingFixingFaceWidthController = TextEditingController();
  final _roomCeilingFramingSpacingController = TextEditingController();
  final _roomCeilingFramingOffsetController = TextEditingController();
  final _roomCeilingFixingFaceWidthController = TextEditingController();
  final _lineStudSpacingController = TextEditingController();
  final _lineStudOffsetController = TextEditingController();
  final _lineFixingFaceWidthController = TextEditingController();
  final _selectedJob = SelectedJob();
  final _selectedTask = SelectedTask();
  final _selectedSupplier = SelectedSupplier();
  final _undo = <_RoomBundle>[];
  final _redo = <_RoomBundle>[];

  late PlasterProject _project;
  Job? _job;
  Task? _task;
  Supplier? _supplier;
  var _selectionMode = false;
  var _snapToGrid = true;
  var _showGrid = true;
  var _fitCanvasRequest = 0;
  var _selectedRoomIndex = 0;
  int? _selectedLineIndex;
  int? _selectedIntersectionIndex;
  int? _selectedOpeningIndex;
  var _hasPendingRoomGesture = false;
  _RoomBundle? _gestureBaseRoom;
  List<_RoomBundle> _rooms = [];
  List<PlasterMaterialSize> _materials = [];
  List<PlasterSurfaceLayout> _layouts = const [];
  var _takeoff = const PlasterTakeoffSummary.zero();
  Isolate? _analysisIsolate;
  ReceivePort? _analysisPort;
  StreamSubscription<dynamic>? _analysisSubscription;
  Completer<void>? _analysisCompleter;
  var _analysisGeneration = 0;
  var _isAnalyzing = false;
  var _analysisTimedOut = false;
  var _analysisReachedTargetWaste = false;
  var _analysisExploredStates = 0;
  var _analysisElapsedMs = 0;
  double? _bestWastePercentSeen;
  Stopwatch? _analysisStopwatch;
  Timer? _analysisTimer;
  var _hasLoadedProjectState = false;

  bool get _isRoomEditorOnly => widget.editorOnlyRoomId != null;

  @override
  Future<void> asyncInitState() => _load();

  Future<void> _load() async {
    final initialProject =
        widget.project ?? (throw StateError('Project required'));
    final project = _hasLoadedProjectState
        ? await DaoPlasterProject().getById(initialProject.id) ?? initialProject
        : initialProject;
    final job = await DaoJob().getById(project.jobId);
    final task = project.taskId == null
        ? null
        : await DaoTask().getById(project.taskId);
    final supplier = project.supplierId == null
        ? null
        : await DaoSupplier().getById(project.supplierId);
    final rooms = await DaoPlasterRoom().getByProject(project.id);
    final bundles = <_RoomBundle>[];
    for (final room in rooms) {
      final lines = await _ensureRoomLines(room);
      final openings = await DaoPlasterRoomOpening().getByLineIds(
        lines.map((line) => line.id).toList(),
      );
      final constraints = await DaoPlasterRoomConstraint().getByRoom(room.id);
      bundles.add(
        _RoomBundle(
          room: room,
          lines: lines,
          openings: openings,
          constraints: constraints,
        ),
      );
    }
    final materials = await _loadMaterialsForSupplier(project.supplierId);
    if (!mounted) {
      return;
    }
    final roomIndex = widget.editorOnlyRoomId == null
        ? 0
        : bundles.indexWhere(
            (bundle) => bundle.room.id == widget.editorOnlyRoomId,
          );
    setState(() {
      _project = project;
      _job = job;
      _task = task;
      _supplier = supplier;
      _rooms = bundles;
      _materials = materials;
      _selectedRoomIndex = bundles.isEmpty ? 0 : max(0, roomIndex);
      _nameController.text = project.name;
      _wasteController.text = project.wastePercent.toString();
      _wallStudSpacingController.text = _formatLengthEntry(
        project.wallStudSpacing,
        roomUnitSystem: bundles.isEmpty
            ? PreferredUnitSystem.metric
            : bundles.first.room.unitSystem,
      );
      _wallStudOffsetController.text = _formatLengthEntry(
        project.wallStudOffset,
        roomUnitSystem: bundles.isEmpty
            ? PreferredUnitSystem.metric
            : bundles.first.room.unitSystem,
      );
      _wallFixingFaceWidthController.text = _formatLengthEntry(
        project.wallFixingFaceWidth,
        roomUnitSystem: bundles.isEmpty
            ? PreferredUnitSystem.metric
            : bundles.first.room.unitSystem,
      );
      _ceilingFramingSpacingController.text = _formatLengthEntry(
        project.ceilingFramingSpacing,
        roomUnitSystem: bundles.isEmpty
            ? PreferredUnitSystem.metric
            : bundles.first.room.unitSystem,
      );
      _ceilingFramingOffsetController.text = _formatLengthEntry(
        project.ceilingFramingOffset,
        roomUnitSystem: bundles.isEmpty
            ? PreferredUnitSystem.metric
            : bundles.first.room.unitSystem,
      );
      _ceilingFixingFaceWidthController.text = _formatLengthEntry(
        project.ceilingFixingFaceWidth,
        roomUnitSystem: bundles.isEmpty
            ? PreferredUnitSystem.metric
            : bundles.first.room.unitSystem,
      );
      _selectedJob.jobId = project.jobId;
      _selectedTask.taskId = project.taskId;
      _selectedSupplier.selected = project.supplierId;
      _hasLoadedProjectState = true;
    });
    _syncRoomControllers();
    if (_isRoomEditorOnly && bundles.isNotEmpty) {
      _logRoomEditorDebugDump(bundles[_selectedRoomIndex]);
    }
    unawaited(_startAnalysis());
  }

  void _logRoomEditorDebugDump(_RoomBundle bundle) {
    final room = bundle.room;
    Log.i('PLASTER_EDITOR_DEBUG_DUMP_START');
    Log.i(
      'room: id=${room.id}, name="${room.name}", '
      'unitSystem=${room.unitSystem.name}, '
      'ceilingHeight=${room.ceilingHeight}',
    );
    Log.i('lines:');

    for (var i = 0; i < bundle.lines.length; i++) {
      final line = bundle.lines[i];
      final end = PlasterGeometry.lineEnd(bundle.lines, i);
      Log.i(
        '  [$i] id=${line.id}, seq=${line.seqNo}, '
        'start=(${line.startX},${line.startY}), '
        'end=(${end.x},${end.y}), '
        'length=${line.length}, '
        'plasterSelected=${line.plasterSelected}, '
        'sheetDirection=${line.sheetDirection.name}',
      );
    }

    Log.i('openings:');
    if (bundle.openings.isEmpty) {
      Log.i('  <none>');
    } else {
      for (final opening in bundle.openings) {
        Log.i(
          '  id=${opening.id}, lineId=${opening.lineId}, '
          'type=${opening.type.name}, '
          'offset=${opening.offsetFromStart}, '
          'width=${opening.width}, height=${opening.height}, '
          'sillHeight=${opening.sillHeight}',
        );
      }
    }

    Log.i('constraints:');
    if (bundle.constraints.isEmpty) {
      Log.i('  <none>');
    } else {
      for (final constraint in bundle.constraints) {
        Log.i(
          '  id=${constraint.id}, lineId=${constraint.lineId}, '
          'type=${constraint.type.name}, '
          'target=${constraint.targetValue}',
        );
      }
    }
    Log.i('PLASTER_EDITOR_DEBUG_DUMP_END');
  }

  Future<List<PlasterRoomLine>> _ensureRoomLines(PlasterRoom room) async {
    final dao = DaoPlasterRoomLine();
    final existing = await dao.getByRoom(room.id);
    if (existing.isNotEmpty) {
      return existing;
    }

    final defaults = PlasterGeometry.defaultLines(
      roomId: room.id,
      unitSystem: room.unitSystem,
    );
    for (final line in defaults) {
      final id = await dao.insert(line);
      line.id = id;
    }
    return dao.getByRoom(room.id);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    unawaited(_stopAnalysis());
    _analysisTimer?.cancel();
    _nameController.dispose();
    _roomNameController.dispose();
    _wasteController.dispose();
    _ceilingHeightController.dispose();
    _wallStudSpacingController.dispose();
    _wallStudOffsetController.dispose();
    _wallFixingFaceWidthController.dispose();
    _ceilingFramingSpacingController.dispose();
    _ceilingFramingOffsetController.dispose();
    _ceilingFixingFaceWidthController.dispose();
    _roomCeilingFramingSpacingController.dispose();
    _roomCeilingFramingOffsetController.dispose();
    _roomCeilingFixingFaceWidthController.dispose();
    _lineStudSpacingController.dispose();
    _lineStudOffsetController.dispose();
    _lineFixingFaceWidthController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver
        ..unsubscribe(this)
        ..subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    unawaited(_load());
  }

  _RoomBundle get _currentRoom => _rooms[_selectedRoomIndex];

  String _formatLengthEntry(
    int value, {
    required PreferredUnitSystem roomUnitSystem,
  }) => PlasterGeometry.formatDisplayLength(
    value,
    roomUnitSystem,
  ).replaceFirst(RegExp(r'\s+[A-Za-z/"]+$'), '');

  int? _parseLengthEntry(
    String value, {
    required PreferredUnitSystem roomUnitSystem,
  }) => PlasterGeometry.parseDisplayLength(value, roomUnitSystem);

  List<PlasterRoomShape> _buildShapes() => [
    for (final bundle in _rooms)
      PlasterRoomShape(
        project: _project,
        room: bundle.room,
        lines: bundle.lines,
        openings: bundle.openings,
      ),
  ];

  bool _isBetterTakeoff(
    PlasterTakeoffSummary candidate,
    PlasterTakeoffSummary baseline,
  ) {
    if (baseline.totalSheetCount == 0 &&
        baseline.totalSheetCountWithWaste == 0) {
      return true;
    }
    if (candidate.totalSheetCountWithWaste !=
        baseline.totalSheetCountWithWaste) {
      return candidate.totalSheetCountWithWaste <
          baseline.totalSheetCountWithWaste;
    }
    if (candidate.totalSheetCount != baseline.totalSheetCount) {
      return candidate.totalSheetCount < baseline.totalSheetCount;
    }
    if (candidate.estimatedWasteArea != baseline.estimatedWasteArea) {
      return candidate.estimatedWasteArea < baseline.estimatedWasteArea;
    }
    if (candidate.estimatedWastePercent != baseline.estimatedWastePercent) {
      return candidate.estimatedWastePercent < baseline.estimatedWastePercent;
    }
    if (candidate.tapeLength != baseline.tapeLength) {
      return candidate.tapeLength < baseline.tapeLength;
    }
    return false;
  }

  Future<void> _stopAnalysis({bool markStopped = true}) async {
    _analysisGeneration++;
    _analysisIsolate?.kill(priority: Isolate.immediate);
    _analysisIsolate = null;
    _analysisTimer?.cancel();
    _analysisTimer = null;
    _analysisStopwatch?.stop();
    _analysisElapsedMs = _analysisStopwatch?.elapsedMilliseconds ?? 0;
    await _analysisSubscription?.cancel();
    _analysisSubscription = null;
    _analysisPort?.close();
    _analysisPort = null;
    if (_analysisCompleter != null && !_analysisCompleter!.isCompleted) {
      _analysisCompleter!.complete();
    }
    _analysisCompleter = null;
    if (markStopped && mounted && _isAnalyzing) {
      setState(() {
        _isAnalyzing = false;
      });
    } else {
      _isAnalyzing = false;
    }
  }

  Future<void> _startAnalysis({bool awaitCompletion = false}) async {
    if (!mounted) {
      return;
    }
    await _stopAnalysis(markStopped: false);
    final shapes = _buildShapes();
    final generation = ++_analysisGeneration;
    if (shapes.isEmpty || _materials.isEmpty) {
      if (mounted) {
        setState(() {
          _layouts = const [];
          _takeoff = const PlasterTakeoffSummary.zero();
          _isAnalyzing = false;
          _analysisTimedOut = false;
          _analysisReachedTargetWaste = false;
          _analysisExploredStates = 0;
          _analysisElapsedMs = 0;
          _bestWastePercentSeen = null;
        });
      }
      return;
    }

    final port = ReceivePort();
    final completer = Completer<void>();
    _analysisStopwatch = Stopwatch()..start();
    _analysisTimer?.cancel();
    _analysisTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || !_isAnalyzing) {
        return;
      }
      final elapsedMs = _analysisStopwatch?.elapsedMilliseconds ?? 0;
      if (elapsedMs == _analysisElapsedMs) {
        return;
      }
      setState(() {
        _analysisElapsedMs = elapsedMs;
      });
    });
    setState(() {
      _analysisPort = port;
      _analysisCompleter = completer;
      _isAnalyzing = true;
      _analysisTimedOut = false;
      _analysisReachedTargetWaste = false;
      _analysisExploredStates = 0;
      _analysisElapsedMs = 0;
      _bestWastePercentSeen = null;
    });
    final request = PlasterAnalysisRequest(
      roomShapes: shapes,
      materials: _materials,
      scoring: await AppSettings.getPlasterLayoutScoring(),
      wastePercent:
          int.tryParse(_wasteController.text.trim()) ?? _project.wastePercent,
    );
    _analysisIsolate = await Isolate.spawn<PlasterAnalysisIsolateRequest>(
      plasterAnalyzeProjectInIsolate,
      PlasterAnalysisIsolateRequest(sendPort: port.sendPort, request: request),
      debugName: 'plasterboard-layout-analysis',
    );
    _analysisSubscription = port.listen((message) {
      if (!mounted || generation != _analysisGeneration) {
        return;
      }
      if (message is PlasterAnalysisProgress) {
        setState(() {
          _analysisExploredStates = message.exploredStates;
          _analysisTimedOut = message.timedOut;
          _analysisReachedTargetWaste = message.reachedTargetWaste;
        });
        return;
      }
      if (message is PlasterAnalysisResult) {
        setState(() {
          _analysisExploredStates = message.exploredStates;
          _analysisTimedOut = message.timedOut;
          _analysisReachedTargetWaste = message.reachedTargetWaste;
          _bestWastePercentSeen = _bestWastePercentSeen == null
              ? message.takeoff.estimatedWastePercent
              : min(
                  _bestWastePercentSeen!,
                  message.takeoff.estimatedWastePercent,
                );
          if (_isBetterTakeoff(message.takeoff, _takeoff)) {
            _layouts = message.layouts;
            _takeoff = message.takeoff;
          }
          if (message.complete) {
            _isAnalyzing = false;
            _analysisElapsedMs =
                _analysisStopwatch?.elapsedMilliseconds ?? message.elapsedMs;
          }
        });
        if (message.complete) {
          unawaited(_stopAnalysis(markStopped: false));
          if (!completer.isCompleted) {
            completer.complete();
          }
        }
        return;
      }
      if (message is PlasterAnalysisFailure) {
        setState(() {
          _isAnalyzing = false;
        });
        hmbScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('Layout analysis failed: ${message.error}')),
        );
        unawaited(_stopAnalysis(markStopped: false));
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });
    if (awaitCompletion) {
      await completer.future;
    }
  }

  void _syncRoomControllers() {
    if (_rooms.isEmpty) {
      return;
    }
    _roomNameController.text = _currentRoom.room.name;
    _ceilingHeightController.text = PlasterGeometry.formatDisplayLength(
      _currentRoom.room.ceilingHeight,
      _currentRoom.room.unitSystem,
    ).replaceFirst(RegExp(r'\s+[A-Za-z/"]+$'), '');
    _roomCeilingFramingSpacingController.text =
        _currentRoom.room.ceilingFramingSpacingOverride == null
        ? ''
        : _formatLengthEntry(
            _currentRoom.room.ceilingFramingSpacingOverride!,
            roomUnitSystem: _currentRoom.room.unitSystem,
          );
    _roomCeilingFramingOffsetController.text =
        _currentRoom.room.ceilingFramingOffsetOverride == null
        ? ''
        : _formatLengthEntry(
            _currentRoom.room.ceilingFramingOffsetOverride!,
            roomUnitSystem: _currentRoom.room.unitSystem,
          );
    _roomCeilingFixingFaceWidthController.text =
        _currentRoom.room.ceilingFixingFaceWidthOverride == null
        ? ''
        : _formatLengthEntry(
            _currentRoom.room.ceilingFixingFaceWidthOverride!,
            roomUnitSystem: _currentRoom.room.unitSystem,
          );
    final selectedLine = _selectedLineIndex == null
        ? null
        : _currentRoom.lines[_selectedLineIndex!];
    _lineStudSpacingController.text = selectedLine?.studSpacingOverride == null
        ? ''
        : _formatLengthEntry(
            selectedLine!.studSpacingOverride!,
            roomUnitSystem: _currentRoom.room.unitSystem,
          );
    _lineStudOffsetController.text = selectedLine?.studOffsetOverride == null
        ? ''
        : _formatLengthEntry(
            selectedLine!.studOffsetOverride!,
            roomUnitSystem: _currentRoom.room.unitSystem,
          );
    _lineFixingFaceWidthController.text =
        selectedLine?.fixingFaceWidthOverride == null
        ? ''
        : _formatLengthEntry(
            selectedLine!.fixingFaceWidthOverride!,
            roomUnitSystem: _currentRoom.room.unitSystem,
          );
  }

  Future<void> _commitRoomName() async {
    final name = _roomNameController.text.trim();
    if (name.isEmpty || name == _currentRoom.room.name) {
      if (name.isEmpty) {
        _syncRoomControllers();
        if (mounted) {
          setState(() {});
        }
      }
      return;
    }
    await _updateCurrentRoom(
      _currentRoom.copyWith(room: _currentRoom.room.copyWith(name: name)),
      trackUndo: false,
    );
  }

  Future<void> _commitCeilingHeight() async {
    final parsed = PlasterGeometry.parseDisplayLength(
      _ceilingHeightController.text,
      _currentRoom.room.unitSystem,
    );
    if (parsed == null) {
      _syncRoomControllers();
      if (mounted) {
        setState(() {});
      }
      return;
    }
    if (parsed == _currentRoom.room.ceilingHeight) {
      return;
    }
    await _updateCurrentRoom(
      _currentRoom.copyWith(
        room: _currentRoom.room.copyWith(ceilingHeight: parsed),
      ),
      trackUndo: false,
    );
  }

  Future<void> _commitPendingRoomEdits() async {
    if (_rooms.isEmpty) {
      return;
    }
    await _commitRoomName();
    await _commitCeilingHeight();
    await _commitSelectedRoomCeilingOverrides();
    await _commitSelectedLineFramingOverrides();
  }

  void _clearSelection() {
    _selectedLineIndex = null;
    _selectedIntersectionIndex = null;
    _selectedOpeningIndex = null;
    if (_rooms.isNotEmpty) {
      _syncRoomControllers();
    }
  }

  Future<void> _saveProject() async {
    await _commitPendingRoomEdits();
    final previousSupplierId = _project.supplierId;
    final selectedSupplierId = _selectedSupplier.selected;
    final updated = _project.copyWith(
      name: _nameController.text.trim().isEmpty
          ? _project.name
          : _nameController.text.trim(),
      jobId: _selectedJob.jobId ?? _project.jobId,
      taskId: _selectedTask.taskId,
      supplierId: selectedSupplierId,
      wastePercent:
          int.tryParse(_wasteController.text.trim()) ?? _project.wastePercent,
      wallStudSpacing:
          _parseLengthEntry(
            _wallStudSpacingController.text,
            roomUnitSystem: _rooms.isEmpty
                ? PreferredUnitSystem.metric
                : _currentRoom.room.unitSystem,
          ) ??
          _project.wallStudSpacing,
      wallStudOffset:
          _parseLengthEntry(
            _wallStudOffsetController.text,
            roomUnitSystem: _rooms.isEmpty
                ? PreferredUnitSystem.metric
                : _currentRoom.room.unitSystem,
          ) ??
          _project.wallStudOffset,
      wallFixingFaceWidth:
          _parseLengthEntry(
            _wallFixingFaceWidthController.text,
            roomUnitSystem: _rooms.isEmpty
                ? PreferredUnitSystem.metric
                : _currentRoom.room.unitSystem,
          ) ??
          _project.wallFixingFaceWidth,
      ceilingFramingSpacing:
          _parseLengthEntry(
            _ceilingFramingSpacingController.text,
            roomUnitSystem: _rooms.isEmpty
                ? PreferredUnitSystem.metric
                : _currentRoom.room.unitSystem,
          ) ??
          _project.ceilingFramingSpacing,
      ceilingFramingOffset:
          _parseLengthEntry(
            _ceilingFramingOffsetController.text,
            roomUnitSystem: _rooms.isEmpty
                ? PreferredUnitSystem.metric
                : _currentRoom.room.unitSystem,
          ) ??
          _project.ceilingFramingOffset,
      ceilingFixingFaceWidth:
          _parseLengthEntry(
            _ceilingFixingFaceWidthController.text,
            roomUnitSystem: _rooms.isEmpty
                ? PreferredUnitSystem.metric
                : _currentRoom.room.unitSystem,
          ) ??
          _project.ceilingFixingFaceWidth,
    );
    await DaoPlasterProject().update(updated);
    _project = updated;
    _job = await DaoJob().getById(updated.jobId);
    _task = updated.taskId == null
        ? null
        : await DaoTask().getById(updated.taskId);
    final supplierSelectionStillCurrent =
        _selectedSupplier.selected == updated.supplierId;
    if (supplierSelectionStillCurrent) {
      _selectedSupplier.selected = updated.supplierId;
      _supplier = updated.supplierId == null
          ? null
          : await DaoSupplier().getById(updated.supplierId);
      if (previousSupplierId != updated.supplierId) {
        _materials = await _loadMaterialsForSupplier(updated.supplierId);
      }
    }
    if (mounted) {
      setState(() {});
    }
    await _startAnalysis();
  }

  Future<void> _updateSelectedSupplier(Supplier? supplier) async {
    final supplierId = supplier?.id;
    if (mounted) {
      setState(() {
        _selectedSupplier.selected = supplierId;
        _supplier = supplier;
      });
    } else {
      _selectedSupplier.selected = supplierId;
      _supplier = supplier;
    }
    await _saveProject();
  }

  Future<void> _commitSelectedLineFramingOverrides() async {
    if (_selectedLineIndex == null || _rooms.isEmpty) {
      return;
    }
    final currentLine = _currentRoom.lines[_selectedLineIndex!];
    final spacingText = _lineStudSpacingController.text.trim();
    final offsetText = _lineStudOffsetController.text.trim();
    final fixingFaceText = _lineFixingFaceWidthController.text.trim();
    final spacing = spacingText.isEmpty
        ? null
        : _parseLengthEntry(
            spacingText,
            roomUnitSystem: _currentRoom.room.unitSystem,
          );
    final offset = offsetText.isEmpty
        ? null
        : _parseLengthEntry(
            offsetText,
            roomUnitSystem: _currentRoom.room.unitSystem,
          );
    final fixingFaceWidth = fixingFaceText.isEmpty
        ? null
        : _parseLengthEntry(
            fixingFaceText,
            roomUnitSystem: _currentRoom.room.unitSystem,
          );
    if ((spacingText.isNotEmpty && spacing == null) ||
        (offsetText.isNotEmpty && offset == null) ||
        (fixingFaceText.isNotEmpty && fixingFaceWidth == null)) {
      _syncRoomControllers();
      if (mounted) {
        setState(() {});
      }
      return;
    }
    if (currentLine.studSpacingOverride == spacing &&
        currentLine.studOffsetOverride == offset &&
        currentLine.fixingFaceWidthOverride == fixingFaceWidth) {
      return;
    }
    final lines = List<PlasterRoomLine>.from(_currentRoom.lines);
    lines[_selectedLineIndex!] = currentLine.copyWith(
      studSpacingOverride: spacing,
      studOffsetOverride: offset,
      fixingFaceWidthOverride: fixingFaceWidth,
    );
    await _updateCurrentRoom(
      _currentRoom.copyWith(lines: lines),
      trackUndo: false,
    );
  }

  Future<void> _commitSelectedRoomCeilingOverrides() async {
    if (_rooms.isEmpty) {
      return;
    }
    final spacingText = _roomCeilingFramingSpacingController.text.trim();
    final offsetText = _roomCeilingFramingOffsetController.text.trim();
    final fixingFaceText = _roomCeilingFixingFaceWidthController.text.trim();
    final spacing = spacingText.isEmpty
        ? null
        : _parseLengthEntry(
            spacingText,
            roomUnitSystem: _currentRoom.room.unitSystem,
          );
    final offset = offsetText.isEmpty
        ? null
        : _parseLengthEntry(
            offsetText,
            roomUnitSystem: _currentRoom.room.unitSystem,
          );
    final fixingFaceWidth = fixingFaceText.isEmpty
        ? null
        : _parseLengthEntry(
            fixingFaceText,
            roomUnitSystem: _currentRoom.room.unitSystem,
          );
    if ((spacingText.isNotEmpty && spacing == null) ||
        (offsetText.isNotEmpty && offset == null) ||
        (fixingFaceText.isNotEmpty && fixingFaceWidth == null)) {
      _syncRoomControllers();
      if (mounted) {
        setState(() {});
      }
      return;
    }
    final room = _currentRoom.room;
    if (room.ceilingFramingSpacingOverride == spacing &&
        room.ceilingFramingOffsetOverride == offset &&
        room.ceilingFixingFaceWidthOverride == fixingFaceWidth) {
      return;
    }
    await _updateCurrentRoom(
      _currentRoom.copyWith(
        room: room.copyWith(
          ceilingFramingSpacingOverride: spacing,
          ceilingFramingOffsetOverride: offset,
          ceilingFixingFaceWidthOverride: fixingFaceWidth,
        ),
      ),
      trackUndo: false,
    );
  }

  Future<void> _openEditorFramingSettings() async {
    if (_rooms.isEmpty || !mounted) {
      return;
    }
    final roomUnitLabel = PlasterGeometry.unitLabel(
      _currentRoom.room.unitSystem,
    );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
          ),
          child: RoomEditorFramingSettingsSheet(
            unitLabel: roomUnitLabel,
            ceilingHeightController: _ceilingHeightController,
            roomCeilingFramingSpacingController:
                _roomCeilingFramingSpacingController,
            roomCeilingFramingOffsetController:
                _roomCeilingFramingOffsetController,
            roomCeilingFixingFaceWidthController:
                _roomCeilingFixingFaceWidthController,
            hasSelectedWall: _selectedLineIndex != null,
            lineStudSpacingController: _lineStudSpacingController,
            lineStudOffsetController: _lineStudOffsetController,
            lineFixingFaceWidthController: _lineFixingFaceWidthController,
            onCommitCeilingHeight: _commitCeilingHeight,
            onCommitSelectedRoomCeilingOverrides:
                _commitSelectedRoomCeilingOverrides,
            onCommitSelectedLineOverrides:
                _commitSelectedLineFramingOverrides,
            onApply: () async {
              await _commitCeilingHeight();
              await _commitSelectedRoomCeilingOverrides();
              await _commitSelectedLineFramingOverrides();
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
      ),
    );
  }

  Future<List<PlasterMaterialSize>> _loadMaterialsForSupplier(
    int? supplierId,
  ) async {
    if (supplierId == null) {
      return [];
    }
    final dao = DaoPlasterMaterialSize();
    final existing = await dao.getBySupplier(supplierId);
    if (existing.isNotEmpty) {
      return existing;
    }

    final unitSystem = _rooms.isNotEmpty
        ? _rooms.first.room.unitSystem
        : (await DaoSystem().get()).preferredUnitSystem;
    final defaults = _defaultMaterialSizes(supplierId, unitSystem);
    for (final size in defaults) {
      final id = await dao.insert(size);
      size.id = id;
    }
    return dao.getBySupplier(supplierId);
  }

  List<PlasterMaterialSize> _defaultMaterialSizes(
    int supplierId,
    PreferredUnitSystem unitSystem,
  ) {
    if (unitSystem == PreferredUnitSystem.metric) {
      return [
        PlasterMaterialSize.forInsert(
          supplierId: supplierId,
          name: '1200 x 2400',
          unitSystem: unitSystem,
          width: 12000,
          height: 24000,
        ),
        PlasterMaterialSize.forInsert(
          supplierId: supplierId,
          name: '1200 x 2700',
          unitSystem: unitSystem,
          width: 12000,
          height: 27000,
        ),
        PlasterMaterialSize.forInsert(
          supplierId: supplierId,
          name: '1200 x 3000',
          unitSystem: unitSystem,
          width: 12000,
          height: 30000,
        ),
      ];
    }
    return [
      PlasterMaterialSize.forInsert(
        supplierId: supplierId,
        name: '4 x 8',
        unitSystem: unitSystem,
        width: 48000,
        height: 96000,
      ),
      PlasterMaterialSize.forInsert(
        supplierId: supplierId,
        name: '4 x 9',
        unitSystem: unitSystem,
        width: 48000,
        height: 108000,
      ),
      PlasterMaterialSize.forInsert(
        supplierId: supplierId,
        name: '4 x 10',
        unitSystem: unitSystem,
        width: 48000,
        height: 120000,
      ),
    ];
  }

  Future<void> _saveRoomBundle(_RoomBundle bundle) async {
    final roomDao = DaoPlasterRoom();
    final lineDao = DaoPlasterRoomLine();
    final openingDao = DaoPlasterRoomOpening();
    final constraintDao = DaoPlasterRoomConstraint();

    await roomDao.withTransaction((transaction) async {
      await roomDao.update(bundle.room, transaction);
      bundle.openings = [
        for (final opening in bundle.openings)
          if (bundle.lines.any((line) => line.id == opening.lineId)) opening,
      ];

      final existingLineRows = await lineDao
          .withinTransaction(transaction)
          .query(
            DaoPlasterRoomLine.tableName,
            where: 'room_id = ?',
            whereArgs: [bundle.room.id],
            orderBy: 'seq_no ASC',
          );
      final existingLines = lineDao.toList(existingLineRows);
      final existingLineIds = existingLines.map((line) => line.id).toSet();
      final lineIdMap = <int, int>{};
      final keptLineIds = <int>{};

      // Move existing lines out of the way first so new seq_no values do not
      // trip the unique(room_id, seq_no) index during resequencing.
      final seqOffset = bundle.lines.length + existingLines.length + 100;
      for (final line in existingLines) {
        await lineDao
            .withinTransaction(transaction)
            .update(
              DaoPlasterRoomLine.tableName,
              {'seq_no': line.seqNo + seqOffset},
              where: 'id = ?',
              whereArgs: [line.id],
            );
      }

      for (var i = 0; i < bundle.lines.length; i++) {
        final previousId = bundle.lines[i].id;
        final line = bundle.lines[i].copyWith(seqNo: i);
        if (line.id < 0) {
          final id = await lineDao.insert(line, transaction);
          line.id = id;
          bundle.lines[i] = line;
          lineIdMap[previousId] = id;
        } else {
          await lineDao.update(line, transaction);
          bundle.lines[i] = line;
          keptLineIds.add(line.id);
        }
        keptLineIds.add(bundle.lines[i].id);
      }

      for (final line in existingLines.where(
        (line) => !keptLineIds.contains(line.id),
      )) {
        await lineDao.delete(line.id, transaction);
      }

      final existingOpeningRows = bundle.lines.isEmpty
          ? <Map<String, Object?>>[]
          : await openingDao
                .withinTransaction(transaction)
                .query(
                  DaoPlasterRoomOpening.tableName,
                  where:
                      'line_id IN ('
                      "${List.filled(bundle.lines.length, '?').join(',')})",
                  whereArgs: bundle.lines.map((line) => line.id).toList(),
                );
      final existingOpenings = openingDao.toList(existingOpeningRows);
      final keptOpeningIds = <int>{};
      for (var i = 0; i < bundle.openings.length; i++) {
        final opening = bundle.openings[i];
        if (!bundle.lines.any((line) => line.id == opening.lineId)) {
          continue;
        }
        if (opening.id < 0) {
          final id = await openingDao.insert(opening, transaction);
          opening.id = id;
        } else {
          await openingDao.update(opening, transaction);
        }
        keptOpeningIds.add(opening.id);
        bundle.openings[i] = opening;
      }
      for (final opening in existingOpenings.where(
        (opening) => !keptOpeningIds.contains(opening.id),
      )) {
        await openingDao.delete(opening.id, transaction);
      }

      if (existingLineIds.difference(keptLineIds).isNotEmpty) {
        final refreshedOpeningRows = bundle.lines.isEmpty
            ? <Map<String, Object?>>[]
            : await openingDao
                  .withinTransaction(transaction)
                  .query(
                    DaoPlasterRoomOpening.tableName,
                    where:
                        'line_id IN ('
                        "${List.filled(bundle.lines.length, '?').join(',')})",
                    whereArgs: bundle.lines.map((line) => line.id).toList(),
                  );
        bundle.openings = openingDao.toList(refreshedOpeningRows);
      }

      final existingConstraintRows = await constraintDao
          .withinTransaction(transaction)
          .query(
            DaoPlasterRoomConstraint.tableName,
            where: 'room_id = ?',
            whereArgs: [bundle.room.id],
          );
      final existingConstraints = constraintDao.toList(existingConstraintRows);
      final keptConstraintIds = <int>{};
      bundle.constraints = [
        for (final constraint in bundle.constraints)
          if (keptLineIds.contains(
            lineIdMap[constraint.lineId] ?? constraint.lineId,
          ))
            constraint.copyWith(
              lineId: lineIdMap[constraint.lineId] ?? constraint.lineId,
            ),
      ];
      for (var i = 0; i < bundle.constraints.length; i++) {
        final constraint = bundle.constraints[i];
        if (constraint.id < 0) {
          final id = await constraintDao.insert(constraint, transaction);
          constraint.id = id;
        } else {
          await constraintDao.update(constraint, transaction);
        }
        keptConstraintIds.add(constraint.id);
        bundle.constraints[i] = constraint;
      }
      for (final constraint in existingConstraints.where(
        (value) => !keptConstraintIds.contains(value.id),
      )) {
        await constraintDao.delete(constraint.id, transaction);
      }
    });
  }

  PlasterRoomConstraint? _constraintForLine(
    int lineId,
    PlasterConstraintType type,
  ) {
    for (final constraint in _currentRoom.constraints) {
      if (constraint.lineId == lineId && constraint.type == type) {
        return constraint;
      }
    }
    return null;
  }

  List<PlasterRoomConstraint> _constraintsWithoutLineType(
    List<PlasterRoomConstraint> constraints,
    int lineId,
    PlasterConstraintType type,
  ) => [
    for (final constraint in constraints)
      if (!(constraint.lineId == lineId && constraint.type == type)) constraint,
  ];

  List<PlasterRoomConstraint> _upsertConstraint(
    List<PlasterRoomConstraint> constraints,
    PlasterRoomConstraint nextConstraint,
  ) {
    final updated = _constraintsWithoutLineType(
      constraints,
      nextConstraint.lineId,
      nextConstraint.type,
    )..add(nextConstraint);
    return updated;
  }

  List<RoomEditorConstraint> _toEditorConstraints(_RoomBundle bundle) => [
    for (final constraint in bundle.constraints)
      RoomEditorConstraint(
        lineId: constraint.lineId,
        type: switch (constraint.type) {
          PlasterConstraintType.lineLength =>
            RoomEditorConstraintType.lineLength,
          PlasterConstraintType.horizontal =>
            RoomEditorConstraintType.horizontal,
          PlasterConstraintType.vertical =>
            RoomEditorConstraintType.vertical,
          PlasterConstraintType.jointAngle =>
            RoomEditorConstraintType.jointAngle,
        },
        targetValue: constraint.targetValue,
      ),
  ];

  List<PlasterRoomLine> _fromEditorSolvedLines(
    _RoomBundle bundle,
    List<RoomEditorLine> solved,
  ) => [
    for (var i = 0; i < bundle.lines.length; i++)
      bundle.lines[i].copyWith(
        seqNo: solved[i].seqNo,
        startX: solved[i].startX,
        startY: solved[i].startY,
        length: solved[i].length,
      ),
  ];

  RoomEditorSolveResult _solveEditorRoom(
    _RoomBundle bundle, {
    int? pinnedVertexIndex,
    IntPoint? pinnedVertexTarget,
  }) => RoomEditorConstraintSolver.solve(
    lines: _toEditorBundle(bundle).lines,
    constraints: _toEditorConstraints(bundle),
    pinnedVertexIndex: pinnedVertexIndex,
    pinnedVertexTarget: pinnedVertexTarget == null
        ? null
        : RoomEditorIntPoint(pinnedVertexTarget.x, pinnedVertexTarget.y),
  );

  void _showSolveError(RoomEditorSolveResult result) {
    if (!mounted) {
      return;
    }
    final violation = result.violations.isEmpty
        ? null
        : result.violations.first;
    final messenger = hmbScaffoldMessengerKey.currentState;
    if (messenger == null) {
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          violation == null
              ? 'Unable to satisfy all constraints.'
              : _formatSolveViolation(violation),
        ),
      ),
    );
  }

  String _formatSolveViolation(RoomEditorConstraintViolation violation) {
    final unitSystem = _currentRoom.room.unitSystem;
    final requestedLength = PlasterGeometry.formatDisplayLength(
      violation.constraint.targetValue ?? 0,
      unitSystem,
    );
    return switch (violation.constraint.type) {
      RoomEditorConstraintType.lineLength =>
        'The requested line length conflicts with existing constraints. '
            'Requested length: $requestedLength.',
      RoomEditorConstraintType.horizontal =>
        'This line cannot remain horizontal '
            'with the current constraints.',
      RoomEditorConstraintType.vertical =>
        'This line cannot remain vertical '
            'with the current constraints.',
      RoomEditorConstraintType.jointAngle =>
        'This joint cannot keep its current angle constraint.',
    };
  }

  Future<void> _solveAndUpdateRoom(
    _RoomBundle bundle, {
    int? pinnedVertexIndex,
    IntPoint? pinnedVertexTarget,
    bool persist = true,
    bool trackUndo = true,
    bool showError = true,
  }) async {
    final result = _solveEditorRoom(
      bundle,
      pinnedVertexIndex: pinnedVertexIndex,
      pinnedVertexTarget: pinnedVertexTarget,
    );
    if (!result.converged) {
      if (showError) {
        _showSolveError(result);
      }
      return;
    }
    final solvedBundle = bundle.copyWith(
      lines: _fromEditorSolvedLines(bundle, result.lines),
    );
    if (persist) {
      await _updateCurrentRoom(solvedBundle, trackUndo: trackUndo);
    } else {
      _replaceCurrentRoomLocally(solvedBundle, trackUndo: trackUndo);
    }
  }

  Future<bool> _trySolveAndUpdateRoom(
    _RoomBundle bundle, {
    int? pinnedVertexIndex,
    IntPoint? pinnedVertexTarget,
    bool persist = true,
    bool trackUndo = true,
  }) async {
    final result = _solveEditorRoom(
      bundle,
      pinnedVertexIndex: pinnedVertexIndex,
      pinnedVertexTarget: pinnedVertexTarget,
    );
    if (!result.converged) {
      return false;
    }
    final solvedBundle = bundle.copyWith(
      lines: _fromEditorSolvedLines(bundle, result.lines),
    );
    if (persist) {
      await _updateCurrentRoom(solvedBundle, trackUndo: trackUndo);
    } else {
      _replaceCurrentRoomLocally(solvedBundle, trackUndo: trackUndo);
    }
    return true;
  }

  void _logLineSelection(String source, int index) {
    if (index < 0 || index >= _currentRoom.lines.length) {
      Log.i('PLASTER_LINE_SELECTED source=$source, index=$index, invalid=true');
      return;
    }
    final line = _currentRoom.lines[index];
    final end = PlasterGeometry.lineEnd(_currentRoom.lines, index);
    Log.i(
      'PLASTER_LINE_SELECTED '
      'source=$source, index=$index, lineId=${line.id}, '
      'start=(${line.startX},${line.startY}), '
      'end=(${end.x},${end.y}), '
      'length=${line.length}',
    );
  }

  void _logAxisToggleStart(
    String axis,
    int index,
    PlasterRoomLine line,
    IntPoint end,
    List<PlasterRoomConstraint> constraints,
  ) {
    Log.i('PLASTER_AXIS_TOGGLE_START');
    Log.i(
      'axis=$axis, selectedLineIndex=$index, lineId=${line.id}, '
      'start=(${line.startX},${line.startY}), end=(${end.x},${end.y}), '
      'length=${line.length}',
    );
    Log.i('constraints=${_formatConstraintList(constraints)}');
  }

  void _logAxisToggleAttempt(
    String name,
    _RoomBundle bundle, {
    int? pinnedVertexIndex,
    IntPoint? pinnedVertexTarget,
  }) {
    final result = _solveEditorRoom(
      bundle,
      pinnedVertexIndex: pinnedVertexIndex,
      pinnedVertexTarget: pinnedVertexTarget,
    );
    final violationText = result.violations.isEmpty
        ? '<none>'
        : result.violations
              .map(
                (violation) =>
                    'lineId=${violation.constraint.lineId},'
                    'type=${violation.constraint.type.name},'
                    'error=${violation.error.toStringAsFixed(1)}',
              )
              .join(' | ');
    final pinnedTargetText = pinnedVertexTarget == null
        ? '<none>'
        : '(${pinnedVertexTarget.x},${pinnedVertexTarget.y})';
    Log.i(
      'PLASTER_AXIS_TOGGLE_ATTEMPT '
      'name=$name, converged=${result.converged}, '
      'pinnedVertexIndex=$pinnedVertexIndex, '
      'pinnedVertexTarget=$pinnedTargetText, '
      'violations=$violationText',
    );
  }

  String _formatConstraintList(List<PlasterRoomConstraint> constraints) {
    if (constraints.isEmpty) {
      return '<none>';
    }
    return constraints
        .map(
          (constraint) =>
              '{lineId=${constraint.lineId},'
              'type=${constraint.type.name},'
              'target=${constraint.targetValue}}',
        )
        .join(', ');
  }

  _RoomBundle _bundleWithAxisProjectedLine(
    _RoomBundle bundle,
    int lineIndex,
    PlasterConstraintType axisType, {
    required bool pinStart,
  }) {
    final lines = List<PlasterRoomLine>.from(bundle.lines);
    final nextIndex = (lineIndex + 1) % lines.length;
    final start = lines[lineIndex];
    final end = PlasterGeometry.lineEnd(lines, lineIndex);

    if (axisType == PlasterConstraintType.horizontal) {
      if (pinStart) {
        lines[nextIndex] = lines[nextIndex].copyWith(startY: start.startY);
      } else {
        lines[lineIndex] = lines[lineIndex].copyWith(startY: end.y);
      }
    } else if (axisType == PlasterConstraintType.vertical) {
      if (pinStart) {
        lines[nextIndex] = lines[nextIndex].copyWith(startX: start.startX);
      } else {
        lines[lineIndex] = lines[lineIndex].copyWith(startX: end.x);
      }
    }

    return bundle.copyWith(lines: lines);
  }

  Future<void> _updateCurrentRoom(
    _RoomBundle bundle, {
    bool trackUndo = true,
  }) async {
    _replaceCurrentRoomLocally(bundle, trackUndo: trackUndo);
    await _persistCurrentRoom(bundle);
  }

  void _replaceCurrentRoomLocally(_RoomBundle bundle, {bool trackUndo = true}) {
    if (trackUndo) {
      _undo.add(_currentRoom.deepCopy());
      _redo.clear();
    }
    final visibleBundle = bundle.deepCopy();
    if (mounted) {
      _rooms[_selectedRoomIndex] = visibleBundle;
      _syncRoomControllers();
      setState(() {});
    }
  }

  void _beginRoomGestureEdit() {
    if (_hasPendingRoomGesture) {
      return;
    }
    _undo.add(_currentRoom.deepCopy());
    _redo.clear();
    _hasPendingRoomGesture = true;
    _gestureBaseRoom = _currentRoom.deepCopy();
  }

  Future<void> _persistCurrentRoom(_RoomBundle bundle) async {
    await _persistRoomBundle(_selectedRoomIndex, bundle);
  }

  Future<void> _persistRoomBundle(int roomIndex, _RoomBundle bundle) async {
    await _saveRoomBundle(bundle);
    if (mounted) {
      _rooms[roomIndex] = bundle.deepCopy();
      if (roomIndex == _selectedRoomIndex) {
        _syncRoomControllers();
      }
      setState(() {});
    }
    await _startAnalysis();
  }

  Future<void> _commitRoomGestureEdit() async {
    if (!_hasPendingRoomGesture || _rooms.isEmpty) {
      return;
    }
    _hasPendingRoomGesture = false;
    _gestureBaseRoom = null;
    await _persistCurrentRoom(_currentRoom.deepCopy());
  }

  Future<void> _previewPdf() async {
    await _commitPendingRoomEdits();
    await _startAnalysis(awaitCompletion: true);
    final shapes = _buildShapes();
    final file = await BlockingUI().runAndWait(
      label: 'Generating Plasterboard PDF',
      () => generatePlasterProjectPdf(
        project: _project,
        job: _job,
        task: _task,
        supplier: _supplier,
        roomShapes: shapes,
        layouts: _layouts,
        takeoff: _takeoff,
      ),
    );
    if (!mounted) {
      return;
    }
    final recipients = _job == null
        ? <String>[]
        : await DaoJob().getEmailsByJob(_project.jobId);
    final preferredRecipient = recipients.isEmpty ? '' : recipients.first;
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PdfPreviewScreen(
          title: _project.name,
          filePath: file.path,
          preferredRecipient: preferredRecipient,
          emailSubject: _project.name,
          emailBody:
              'Please find attached the plasterboard layout for '
              '${_project.name}.',
          sendEmailDialog:
              ({
                preferredRecipient = '',
                subject = '',
                body = '',
                attachmentPaths = const [],
              }) => EmailDialog(
                preferredRecipient: preferredRecipient,
                subject: subject,
                body: body,
                attachmentPaths: attachmentPaths,
                emailRecipients: [
                  ...recipients,
                  if (preferredRecipient.isNotEmpty &&
                      !recipients.contains(preferredRecipient))
                    preferredRecipient,
                ],
              ),
          canEmail: () async => EmailBlocked(blocked: false, reason: ''),
          onSent: () async {},
        ),
      ),
    );
  }

  Future<void> _reanalyzeLayout() async {
    await _commitPendingRoomEdits();
    await _startAnalysis();
  }

  Future<void> _splitLine(int index) async {
    final line = _currentRoom.lines[index];
    final horizontalConstraint = _constraintForLine(
      line.id,
      PlasterConstraintType.horizontal,
    );
    final verticalConstraint = _constraintForLine(
      line.id,
      PlasterConstraintType.vertical,
    );
    final lines = PlasterGeometry.splitLine(_currentRoom.lines, index);
    final insertedLine = lines[index + 1];
    var constraints = _currentRoom.constraints.where((constraint) {
      if (constraint.lineId != line.id) {
        return true;
      }
      return constraint.type == PlasterConstraintType.horizontal ||
          constraint.type == PlasterConstraintType.vertical;
    }).toList();
    if (horizontalConstraint != null) {
      constraints = _upsertConstraint(
        constraints,
        PlasterRoomConstraint.forInsert(
          roomId: _currentRoom.room.id,
          lineId: insertedLine.id,
          type: PlasterConstraintType.horizontal,
        ),
      );
    }
    if (verticalConstraint != null) {
      constraints = _upsertConstraint(
        constraints,
        PlasterRoomConstraint.forInsert(
          roomId: _currentRoom.room.id,
          lineId: insertedLine.id,
          type: PlasterConstraintType.vertical,
        ),
      );
    }
    await _solveAndUpdateRoom(
      _currentRoom.copyWith(lines: lines, constraints: constraints),
    );
  }

  Future<void> _editLineLengthConstraint(int index) async {
    final line = _currentRoom.lines[index];
    final lengthConstraint = _constraintForLine(
      line.id,
      PlasterConstraintType.lineLength,
    );
    final length = await showDialog<int>(
      context: context,
      builder: (_) => _LengthDialog(
        unitSystem: _currentRoom.room.unitSystem,
        initialValue: _currentRoom.lines[index].length,
      ),
    );
    if (length == null) {
      return;
    }
    final adjustedLines = PlasterGeometry.setLength(
      _currentRoom.lines,
      index,
      length,
    );
    final constraints = _upsertConstraint(
      _constraintsWithoutLineType(
        _currentRoom.constraints,
        line.id,
        PlasterConstraintType.lineLength,
      ),
      (lengthConstraint ??
              PlasterRoomConstraint.forInsert(
                roomId: _currentRoom.room.id,
                lineId: line.id,
                type: PlasterConstraintType.lineLength,
              ))
          .copyWith(targetValue: length),
    );
    await _solveAndUpdateRoom(
      _currentRoom.copyWith(lines: adjustedLines, constraints: constraints),
    );
  }

  Future<void> _removeLineLengthConstraint(int index) async {
    final line = _currentRoom.lines[index];
    final constraints = _constraintsWithoutLineType(
      _currentRoom.constraints,
      line.id,
      PlasterConstraintType.lineLength,
    );
    await _solveAndUpdateRoom(_currentRoom.copyWith(constraints: constraints));
  }

  Future<void> _toggleLinePlasterSelected(int index) async {
    final lines = List<PlasterRoomLine>.from(_currentRoom.lines);
    final line = lines[index];
    lines[index] = line.copyWith(plasterSelected: !line.plasterSelected);
    await _updateCurrentRoom(_currentRoom.copyWith(lines: lines));
  }

  Future<void> _addOpeningToLine(int index, PlasterOpeningType type) async {
    final line = _currentRoom.lines[index];
    final lengthConstraint = _constraintForLine(
      line.id,
      PlasterConstraintType.lineLength,
    );

    final opening = await showDialog<PlasterRoomOpening>(
      context: context,
      builder: (_) => _OpeningDialog(
        lineId: _currentRoom.lines[index].id,
        unitSystem: _currentRoom.room.unitSystem,
        type: type,
      ),
    );
    if (opening == null) {
      return;
    }
    final centeredOpening = opening.copyWith(
      offsetFromStart: max(0, (line.length - opening.width) ~/ 2),
    );
    final lines = PlasterGeometry.ensureLineLength(
      _currentRoom.lines,
      index,
      centeredOpening.width,
    );
    final constraints = _upsertConstraint(
      _constraintsWithoutLineType(
        _currentRoom.constraints,
        line.id,
        PlasterConstraintType.lineLength,
      ),
      (lengthConstraint ??
              PlasterRoomConstraint.forInsert(
                roomId: _currentRoom.room.id,
                lineId: line.id,
                type: PlasterConstraintType.lineLength,
              ))
          .copyWith(targetValue: max(line.length, opening.width)),
    );
    final bundle = _currentRoom.copyWith(
      lines: lines,
      openings: [..._currentRoom.openings, centeredOpening],
      constraints: constraints,
    );
    await _solveAndUpdateRoom(bundle);
  }

  int _lineIndexForOpening(PlasterRoomOpening opening) =>
      _currentRoom.lines.indexWhere((line) => line.id == opening.lineId);

  Future<void> _editOpening(int index) async {
    final opening = _currentRoom.openings[index];
    final lineIndex = _lineIndexForOpening(opening);
    if (lineIndex < 0) {
      return;
    }
    final updated = await showDialog<PlasterRoomOpening>(
      context: context,
      builder: (_) => _OpeningDialog(
        lineId: opening.lineId,
        unitSystem: _currentRoom.room.unitSystem,
        type: opening.type,
        initialOpening: opening,
        title: opening.type == PlasterOpeningType.door
            ? 'Edit Door'
            : 'Edit Window',
        confirmLabel: 'Save',
      ),
    );
    if (updated == null) {
      return;
    }

    final lines = PlasterGeometry.ensureLineLength(
      _currentRoom.lines,
      lineIndex,
      updated.width,
    );
    final line = _currentRoom.lines[lineIndex];
    final lengthConstraint = _constraintForLine(
      line.id,
      PlasterConstraintType.lineLength,
    );
    final maxOffset = max(0, lines[lineIndex].length - updated.width);
    final openings = List<PlasterRoomOpening>.from(_currentRoom.openings);
    openings[index] = updated.copyWith(
      offsetFromStart: updated.offsetFromStart.clamp(0, maxOffset),
    );
    final constraints = lengthConstraint == null
        ? _currentRoom.constraints
        : _upsertConstraint(
            _constraintsWithoutLineType(
              _currentRoom.constraints,
              line.id,
              PlasterConstraintType.lineLength,
            ),
            lengthConstraint.copyWith(
              targetValue: max(
                lengthConstraint.targetValue ?? 0,
                updated.width,
              ),
            ),
          );
    await _solveAndUpdateRoom(
      _currentRoom.copyWith(
        lines: lines,
        openings: openings,
        constraints: constraints,
      ),
    );
  }

  Future<void> _deleteOpening(int index) async {
    final openings = List<PlasterRoomOpening>.from(_currentRoom.openings)
      ..removeAt(index);
    await _updateCurrentRoom(_currentRoom.copyWith(openings: openings));
    if (!mounted) {
      return;
    }
    setState(() => _selectedOpeningIndex = null);
  }

  PreferredUnitSystem _unitSystemForLayout(PlasterSurfaceLayout layout) =>
      _rooms
          .firstWhere((bundle) => bundle.room.id == layout.roomId)
          .room
          .unitSystem;

  _RoomBundle _bundleForLayout(PlasterSurfaceLayout layout) =>
      _rooms.firstWhere((bundle) => bundle.room.id == layout.roomId);

  PlasterSheetDirection _storedDirectionForLayout(PlasterSurfaceLayout layout) {
    final bundle = _bundleForLayout(layout);
    if (layout.isCeiling) {
      return bundle.room.ceilingSheetDirection;
    }
    final line = bundle.lines.firstWhere((line) => line.id == layout.lineId);
    return line.sheetDirection;
  }

  Future<void> _setSurfaceDirection(
    PlasterSurfaceLayout layout,
    PlasterSheetDirection direction,
  ) async {
    final bundle = _bundleForLayout(layout);
    final roomIndex = _rooms.indexWhere(
      (room) => room.room.id == layout.roomId,
    );
    if (roomIndex < 0) {
      return;
    }

    if (layout.isCeiling) {
      final updated = bundle.copyWith(
        room: bundle.room.copyWith(ceilingSheetDirection: direction),
      );
      await _persistRoomBundle(roomIndex, updated);
      return;
    }

    final lineIndex = bundle.lines.indexWhere(
      (line) => line.id == layout.lineId,
    );
    if (lineIndex < 0) {
      return;
    }
    final lines = List<PlasterRoomLine>.from(bundle.lines);
    lines[lineIndex] = lines[lineIndex].copyWith(sheetDirection: direction);
    final updated = bundle.copyWith(lines: lines);
    await _persistRoomBundle(roomIndex, updated);
  }

  void _openLayoutViewer(PlasterSurfaceLayout layout) {
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _SurfaceLayoutViewerScreen(
            layout: layout,
            unitSystem: _unitSystemForLayout(layout),
          ),
        ),
      ),
    );
  }

  List<PlasterRoomShape> _roomShapesForLayouts() => [
    for (final bundle in _rooms)
      PlasterRoomShape(
        project: _project,
        room: bundle.room,
        lines: bundle.lines,
        openings: bundle.openings,
      ),
  ];

  void _openSheetExplorer(List<PlasterSurfaceLayout> layouts) {
    final sheets = PlasterGeometry.buildProjectSheetExplorer(
      _roomShapesForLayouts(),
      layouts,
    );
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              _ProjectSheetExplorerScreen(sheets: sheets, layouts: layouts),
        ),
      ),
    );
  }

  String _formatKg(double value) => value.toStringAsFixed(value < 10 ? 1 : 0);

  void _moveOpeningLocally(int index, IntPoint point, int anchorOffset) {
    final opening = _currentRoom.openings[index];
    final lineIndex = _lineIndexForOpening(opening);
    if (lineIndex < 0) {
      return;
    }
    final line = _currentRoom.lines[lineIndex];
    final end = PlasterGeometry.lineEnd(_currentRoom.lines, lineIndex);
    final dx = end.x - line.startX;
    final dy = end.y - line.startY;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared == 0) {
      return;
    }
    final projected =
        ((point.x - line.startX) * dx + (point.y - line.startY) * dy) /
        lengthSquared;
    final offset = (projected * line.length).round() - anchorOffset;
    final maxOffset = max(0, line.length - opening.width);
    final openings = List<PlasterRoomOpening>.from(_currentRoom.openings);
    openings[index] = opening.copyWith(
      offsetFromStart: offset.clamp(0, maxOffset),
    );
    _replaceCurrentRoomLocally(
      _currentRoom.copyWith(openings: openings),
      trackUndo: false,
    );
  }

  Future<void> _toggleHorizontalConstraint(int index) async {
    final line = _currentRoom.lines[index];
    final hasHorizontalConstraint =
        _constraintForLine(line.id, PlasterConstraintType.horizontal) != null;
    final constraints = !hasHorizontalConstraint
        ? _upsertConstraint(
            _constraintsWithoutLineType(
              _constraintsWithoutLineType(
                _currentRoom.constraints,
                line.id,
                PlasterConstraintType.vertical,
              ),
              line.id,
              PlasterConstraintType.horizontal,
            ),
            PlasterRoomConstraint.forInsert(
              roomId: _currentRoom.room.id,
              lineId: line.id,
              type: PlasterConstraintType.horizontal,
            ),
          )
        : _constraintsWithoutLineType(
            _currentRoom.constraints,
            line.id,
            PlasterConstraintType.horizontal,
          );
    final bundle = _currentRoom.copyWith(constraints: constraints);
    if (hasHorizontalConstraint) {
      await _solveAndUpdateRoom(bundle);
      return;
    }

    final lineEnd = PlasterGeometry.lineEnd(_currentRoom.lines, index);
    final nextIndex = (index + 1) % _currentRoom.lines.length;
    _logAxisToggleStart('horizontal', index, line, lineEnd, constraints);
    final startPinnedBundle = _bundleWithAxisProjectedLine(
      bundle,
      index,
      PlasterConstraintType.horizontal,
      pinStart: true,
    );
    final endPinnedBundle = _bundleWithAxisProjectedLine(
      bundle,
      index,
      PlasterConstraintType.horizontal,
      pinStart: false,
    );
    _logAxisToggleAttempt(
      'start-pinned',
      startPinnedBundle,
      pinnedVertexIndex: index,
      pinnedVertexTarget: IntPoint(line.startX, line.startY),
    );
    _logAxisToggleAttempt(
      'end-pinned',
      endPinnedBundle,
      pinnedVertexIndex: nextIndex,
      pinnedVertexTarget: lineEnd,
    );
    _logAxisToggleAttempt('free', bundle);
    final solved =
        await _trySolveAndUpdateRoom(
          startPinnedBundle,
          pinnedVertexIndex: index,
          pinnedVertexTarget: IntPoint(line.startX, line.startY),
        ) ||
        await _trySolveAndUpdateRoom(
          endPinnedBundle,
          pinnedVertexIndex: nextIndex,
          pinnedVertexTarget: lineEnd,
        ) ||
        await _trySolveAndUpdateRoom(bundle);
    if (!solved) {
      _showSolveError(_solveEditorRoom(bundle));
    }
  }

  Future<void> _toggleVerticalConstraint(int index) async {
    final line = _currentRoom.lines[index];
    final hasVerticalConstraint =
        _constraintForLine(line.id, PlasterConstraintType.vertical) != null;
    final constraints = !hasVerticalConstraint
        ? _upsertConstraint(
            _constraintsWithoutLineType(
              _constraintsWithoutLineType(
                _currentRoom.constraints,
                line.id,
                PlasterConstraintType.horizontal,
              ),
              line.id,
              PlasterConstraintType.vertical,
            ),
            PlasterRoomConstraint.forInsert(
              roomId: _currentRoom.room.id,
              lineId: line.id,
              type: PlasterConstraintType.vertical,
            ),
          )
        : _constraintsWithoutLineType(
            _currentRoom.constraints,
            line.id,
            PlasterConstraintType.vertical,
          );
    final bundle = _currentRoom.copyWith(constraints: constraints);
    if (hasVerticalConstraint) {
      await _solveAndUpdateRoom(bundle);
      return;
    }

    final lineEnd = PlasterGeometry.lineEnd(_currentRoom.lines, index);
    final nextIndex = (index + 1) % _currentRoom.lines.length;
    _logAxisToggleStart('vertical', index, line, lineEnd, constraints);
    final startPinnedBundle = _bundleWithAxisProjectedLine(
      bundle,
      index,
      PlasterConstraintType.vertical,
      pinStart: true,
    );
    final endPinnedBundle = _bundleWithAxisProjectedLine(
      bundle,
      index,
      PlasterConstraintType.vertical,
      pinStart: false,
    );
    _logAxisToggleAttempt(
      'start-pinned',
      startPinnedBundle,
      pinnedVertexIndex: index,
      pinnedVertexTarget: IntPoint(line.startX, line.startY),
    );
    _logAxisToggleAttempt(
      'end-pinned',
      endPinnedBundle,
      pinnedVertexIndex: nextIndex,
      pinnedVertexTarget: lineEnd,
    );
    _logAxisToggleAttempt('free', bundle);
    final solved =
        await _trySolveAndUpdateRoom(
          startPinnedBundle,
          pinnedVertexIndex: index,
          pinnedVertexTarget: IntPoint(line.startX, line.startY),
        ) ||
        await _trySolveAndUpdateRoom(
          endPinnedBundle,
          pinnedVertexIndex: nextIndex,
          pinnedVertexTarget: lineEnd,
        ) ||
        await _trySolveAndUpdateRoom(bundle);
    if (!solved) {
      _showSolveError(_solveEditorRoom(bundle));
    }
  }

  Future<void> _deleteIntersection(int index) async {
    final angleConstraint = _constraintForLine(
      _currentRoom.lines[index].id,
      PlasterConstraintType.jointAngle,
    );
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Join line'),
              onTap: () => Navigator.of(context).pop('join'),
            ),
            ListTile(
              title: Text(
                angleConstraint == null
                    ? 'Set angle constraint'
                    : 'Change angle constraint',
              ),
              onTap: () => Navigator.of(context).pop('angle'),
            ),
            if (angleConstraint != null)
              ListTile(
                title: const Text('Remove angle constraint'),
                onTap: () => Navigator.of(context).pop('remove-angle'),
              ),
          ],
        ),
      ),
    );
    if (action == null) {
      return;
    }
    if (action == 'angle') {
      if (!mounted) {
        return;
      }
      final angleValue = await showDialog<int>(
        context: context,
        builder: (_) => _AngleDialog(
          initialValue:
              angleConstraint?.targetValue ??
              RoomEditorConstraintSolver.currentAngleValue(
                _toEditorBundle(_currentRoom).lines,
                index,
              ),
        ),
      );
      if (angleValue == null) {
        return;
      }
      final constraints = _upsertConstraint(
        _currentRoom.constraints,
        (angleConstraint ??
                PlasterRoomConstraint.forInsert(
                  roomId: _currentRoom.room.id,
                  lineId: _currentRoom.lines[index].id,
                  type: PlasterConstraintType.jointAngle,
                ))
            .copyWith(targetValue: angleValue),
      );
      await _solveAndUpdateRoom(
        _currentRoom.copyWith(constraints: constraints),
      );
      return;
    }
    if (action == 'remove-angle') {
      final constraints = _constraintsWithoutLineType(
        _currentRoom.constraints,
        _currentRoom.lines[index].id,
        PlasterConstraintType.jointAngle,
      );
      await _solveAndUpdateRoom(
        _currentRoom.copyWith(constraints: constraints),
      );
      return;
    }
    final removedLineId = _currentRoom.lines[index].id;
    final lines = PlasterGeometry.deleteIntersection(_currentRoom.lines, index);
    final constraints = [
      for (final constraint in _currentRoom.constraints)
        if (constraint.lineId != removedLineId) constraint,
    ];
    await _solveAndUpdateRoom(
      _currentRoom.copyWith(lines: lines, constraints: constraints),
    );
  }

  Future<void> _editAngleConstraint(int index) async {
    final angleConstraint = _constraintForLine(
      _currentRoom.lines[index].id,
      PlasterConstraintType.jointAngle,
    );
    final angleValue = await showDialog<int>(
      context: context,
      builder: (_) => _AngleDialog(
        initialValue:
            angleConstraint?.targetValue ??
            RoomEditorConstraintSolver.currentAngleValue(
              _toEditorBundle(_currentRoom).lines,
              index,
            ),
      ),
    );
    if (angleValue == null) {
      return;
    }
    final constraints = _upsertConstraint(
      _currentRoom.constraints,
      (angleConstraint ??
              PlasterRoomConstraint.forInsert(
                roomId: _currentRoom.room.id,
                lineId: _currentRoom.lines[index].id,
                type: PlasterConstraintType.jointAngle,
              ))
          .copyWith(targetValue: angleValue),
    );
    await _solveAndUpdateRoom(_currentRoom.copyWith(constraints: constraints));
  }

  Future<void> _removeAngleConstraint(int index) async {
    final constraints = _constraintsWithoutLineType(
      _currentRoom.constraints,
      _currentRoom.lines[index].id,
      PlasterConstraintType.jointAngle,
    );
    await _solveAndUpdateRoom(_currentRoom.copyWith(constraints: constraints));
  }

  Widget _buildEditorToolbar({
    bool vertical = false,
    bool wrap = false,
    bool constraintsOnly = false,
    bool excludeConstraints = false,
  }) {
    final hasLine = _selectedLineIndex != null;
    final hasIntersection = _selectedIntersectionIndex != null;
    final hasOpening = _selectedOpeningIndex != null;
    final selectedLine = hasLine
        ? _currentRoom.lines[_selectedLineIndex!]
        : null;
    final selectedOpening = hasOpening
        ? _currentRoom.openings[_selectedOpeningIndex!]
        : null;
    final hasLineLengthConstraint =
        selectedLine != null &&
        _constraintForLine(selectedLine.id, PlasterConstraintType.lineLength) !=
            null;
    final hasHorizontalConstraint =
        selectedLine != null &&
        _constraintForLine(selectedLine.id, PlasterConstraintType.horizontal) !=
            null;
    final hasVerticalConstraint =
        selectedLine != null &&
        _constraintForLine(selectedLine.id, PlasterConstraintType.vertical) !=
            null;
    final selectedIntersectionLine = hasIntersection
        ? _currentRoom.lines[_selectedIntersectionIndex!]
        : null;
    final hasAngleConstraint =
        selectedIntersectionLine != null &&
        _constraintForLine(
              selectedIntersectionLine.id,
              PlasterConstraintType.jointAngle,
            ) !=
            null;
    final isSelectedLinePlaster = selectedLine?.plasterSelected ?? false;
    final toolbarButtons = buildRoomEditorToolbarActions(
      state: RoomEditorToolbarState(
        selectionMode: _selectionMode,
        snapToGrid: _snapToGrid,
        showGrid: _showGrid,
        hasLine: hasLine,
        hasIntersection: hasIntersection,
        hasOpening: hasOpening,
        hasLineLengthConstraint: hasLineLengthConstraint,
        hasHorizontalConstraint: hasHorizontalConstraint,
        hasVerticalConstraint: hasVerticalConstraint,
        hasAngleConstraint: hasAngleConstraint,
        isSelectedLinePlaster: isSelectedLinePlaster,
        isSelectedOpeningDoor:
            selectedOpening?.type == PlasterOpeningType.door,
      ),
      callbacks: RoomEditorToolbarCallbacks(
        onToggleSelectionMode: () =>
            setState(() => _selectionMode = !_selectionMode),
        onUndo: _undo.isEmpty
            ? null
            : () async {
                if (_undo.isEmpty) {
                  return;
                }
                _redo.add(_currentRoom.deepCopy());
                final previous = _undo.removeLast();
                _rooms[_selectedRoomIndex] = previous;
                await _saveRoomBundle(previous);
                _syncRoomControllers();
                setState(() {});
              },
        onRedo: _redo.isEmpty
            ? null
            : () async {
                if (_redo.isEmpty) {
                  return;
                }
                _undo.add(_currentRoom.deepCopy());
                final next = _redo.removeLast();
                _rooms[_selectedRoomIndex] = next;
                await _saveRoomBundle(next);
                _syncRoomControllers();
                setState(() {});
              },
        onFit: () => setState(() => _fitCanvasRequest++),
        onToggleSnapToGrid: () => setState(() => _snapToGrid = !_snapToGrid),
        onToggleShowGrid: () => setState(() => _showGrid = !_showGrid),
        onDeselect: () => setState(_clearSelection),
        onSplit: hasLine ? () => _splitLine(_selectedLineIndex!) : null,
        onAddDoor: hasLine
            ? () => _addOpeningToLine(
                _selectedLineIndex!,
                PlasterOpeningType.door,
              )
            : null,
        onAddWindow: hasLine
            ? () => _addOpeningToLine(
                _selectedLineIndex!,
                PlasterOpeningType.window,
              )
            : null,
        onEditOpening: hasOpening
            ? () => _editOpening(_selectedOpeningIndex!)
            : null,
        onDeleteOpening: hasOpening
            ? () => _deleteOpening(_selectedOpeningIndex!)
            : null,
        onToggleLinePlaster: hasLine
            ? () => _toggleLinePlasterSelected(_selectedLineIndex!)
            : null,
        onToggleLineLength: hasLine
            ? () {
                if (hasLineLengthConstraint) {
                  unawaited(_removeLineLengthConstraint(_selectedLineIndex!));
                } else {
                  unawaited(_editLineLengthConstraint(_selectedLineIndex!));
                }
              }
            : null,
        onToggleHorizontal: hasLine
            ? () => _toggleHorizontalConstraint(_selectedLineIndex!)
            : null,
        onToggleVertical: hasLine
            ? () => _toggleVerticalConstraint(_selectedLineIndex!)
            : null,
        onJointAction: hasIntersection
            ? () => _deleteIntersection(_selectedIntersectionIndex!)
            : null,
        onToggleAngle: hasIntersection
            ? () {
                if (hasAngleConstraint) {
                  unawaited(
                    _removeAngleConstraint(_selectedIntersectionIndex!),
                  );
                } else {
                  unawaited(_editAngleConstraint(_selectedIntersectionIndex!));
                }
              }
            : null,
      ),
      constraintsOnly: constraintsOnly,
      excludeConstraints: excludeConstraints,
    );
    return PlasterboardEditorToolbar(
      actions: toolbarButtons,
      vertical: vertical,
      wrap: wrap,
    );
  }

  Widget _buildRoomCanvas() => RoomEditorCanvas(
    bundle: _toEditorBundle(_currentRoom),
    selectionMode: _selectionMode,
    snapToGrid: _snapToGrid,
    showGrid: _showGrid,
    fitRequestId: _fitCanvasRequest,
    selection: RoomEditorSelection(
      selectedLineIndex: _selectedLineIndex,
      selectedIntersectionIndex: _selectedIntersectionIndex,
      selectedOpeningIndex: _selectedOpeningIndex,
    ),
    callbacks: RoomEditorCanvasCallbacks(
      onStartMoveIntersection: _beginRoomGestureEdit,
      onMoveIntersection: (index, point) {
        final baseRoom = _gestureBaseRoom ?? _currentRoom;
        final worldPoint = _fromEditorPoint(point);
        final target = _snapToGrid
            ? PlasterGeometry.snapPoint(worldPoint, baseRoom.room.unitSystem)
            : worldPoint;
        final lines = PlasterGeometry.moveIntersection(
          baseRoom.lines,
          index,
          target,
        );
        unawaited(
          _solveAndUpdateRoom(
            baseRoom.copyWith(lines: lines),
            pinnedVertexIndex: index,
            pinnedVertexTarget: target,
            persist: false,
            trackUndo: false,
            showError: false,
          ),
        );
      },
      onEndMoveIntersection: () async {
        await _commitRoomGestureEdit();
      },
      onStartMoveOpening: _beginRoomGestureEdit,
      onMoveOpening: (index, point, anchorOffset) =>
          _moveOpeningLocally(index, _fromEditorPoint(point), anchorOffset),
      onEndMoveOpening: () async {
        await _commitRoomGestureEdit();
      },
      onTapIntersection: (index) async {
        setState(() {
          _selectedIntersectionIndex = index;
          _selectedLineIndex = null;
          _selectedOpeningIndex = null;
        });
        _syncRoomControllers();
      },
      onTapOpening: (index) async {
        setState(() {
          _selectedOpeningIndex = index;
          _selectedLineIndex = null;
          _selectedIntersectionIndex = null;
        });
        _syncRoomControllers();
      },
      onTapLine: (index) async {
        _logLineSelection('tap', index);
        setState(() {
          _selectedLineIndex = index;
          _selectedIntersectionIndex = null;
          _selectedOpeningIndex = null;
        });
        _syncRoomControllers();
        if (_selectionMode) {
          final lines = List<PlasterRoomLine>.from(_currentRoom.lines);
          final line = lines[index];
          lines[index] = line.copyWith(plasterSelected: !line.plasterSelected);
          await _updateCurrentRoom(_currentRoom.copyWith(lines: lines));
        }
      },
      onTapCeiling: () async {
        if (!_selectionMode) {
          return;
        }
        await _updateCurrentRoom(
          _currentRoom.copyWith(
            room: _currentRoom.room.copyWith(
              plasterCeiling: !_currentRoom.room.plasterCeiling,
            ),
          ),
        );
      },
    ),
  );

  RoomEditorBundle _toEditorBundle(_RoomBundle bundle) => buildRoomEditorBundle(
    roomName: bundle.room.name,
    unitSystem: bundle.room.unitSystem == PreferredUnitSystem.metric
        ? RoomEditorUnitSystem.metric
        : RoomEditorUnitSystem.imperial,
    plasterCeiling: bundle.room.plasterCeiling,
    lines: [
      for (final line in bundle.lines)
        (
          id: line.id,
          seqNo: line.seqNo,
          startX: line.startX,
          startY: line.startY,
          length: line.length,
          plasterSelected: line.plasterSelected,
        ),
    ],
    openings: [
      for (final opening in bundle.openings)
        (
          id: opening.id,
          lineId: opening.lineId,
          type: opening.type == PlasterOpeningType.door
              ? RoomEditorOpeningType.door
              : RoomEditorOpeningType.window,
          offsetFromStart: opening.offsetFromStart,
          width: opening.width,
          height: opening.height,
        ),
    ],
  );

  IntPoint _fromEditorPoint(RoomEditorIntPoint point) =>
      IntPoint(point.x, point.y);

  Widget _buildRoomEditorSection(bool isMobileLandscape) {
    if (_rooms.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Text('This project does not have any rooms yet.'),
      );
    }

    if (_isRoomEditorOnly) {
      return LayoutBuilder(
        builder: (context, constraints) => RoomEditorShell(
          landscape: isMobileLandscape,
          editorOnly: true,
          primaryTools: _buildEditorToolbar(
            vertical: isMobileLandscape,
            wrap: !isMobileLandscape && constraints.maxWidth < 520,
            excludeConstraints: isMobileLandscape,
          ),
          canvas: _buildRoomCanvas(),
          constraintTools: isMobileLandscape
              ? _buildEditorToolbar(
                  vertical: true,
                  constraintsOnly: true,
                )
              : null,
        ),
      );
    }

    final roomUnitLabel = PlasterGeometry.unitLabel(
      _currentRoom.room.unitSystem,
    );
    final roomFields = RoomEditorDetailsForm(
      roomId: _currentRoom.room.id,
      unitSystem:
          _currentRoom.room.unitSystem == PreferredUnitSystem.metric
              ? RoomEditorUnitSystem.metric
              : RoomEditorUnitSystem.imperial,
      unitLabel: roomUnitLabel,
      roomNameController: _roomNameController,
      ceilingHeightController: _ceilingHeightController,
      selectedLineId: _selectedLineIndex == null
          ? null
          : _currentRoom.lines[_selectedLineIndex!].id,
      lineStudSpacingController: _lineStudSpacingController,
      lineStudOffsetController: _lineStudOffsetController,
      onUnitChanged: (value) async {
        if (value == null) {
          return;
        }
        final target = value == RoomEditorUnitSystem.metric
            ? PreferredUnitSystem.metric
            : PreferredUnitSystem.imperial;
        final converted = PlasterGeometry.convertRoomBundle(
          room: _currentRoom.room,
          lines: _currentRoom.lines,
          openings: _currentRoom.openings,
          target: target,
        );
        await _updateCurrentRoom(
          _currentRoom.copyWith(
            room: converted.$1,
            lines: converted.$2,
            openings: converted.$3,
          ),
          trackUndo: false,
        );
      },
      onCommitRoomName: _commitRoomName,
      onCommitCeilingHeight: _commitCeilingHeight,
      onCommitSelectedLineOverrides: _commitSelectedLineFramingOverrides,
      editorTools: LayoutBuilder(
        builder: (context, constraints) =>
            _buildEditorToolbar(wrap: constraints.maxWidth < 520),
      ),
      canvas: _buildRoomCanvas(),
    );

    if (isMobileLandscape) {
      return RoomEditorShell(
        landscape: true,
        primaryTools: _buildEditorToolbar(
          vertical: true,
          excludeConstraints: true,
        ),
        canvas: _buildRoomCanvas(),
        constraintTools: _buildEditorToolbar(
          vertical: true,
          constraintsOnly: true,
        ),
      );
    }

    return roomFields;
  }

  String _roomNameForLayout(PlasterSurfaceLayout layout) {
    for (final bundle in _rooms) {
      if (bundle.room.id == layout.roomId) {
        return bundle.room.name;
      }
    }
    return 'Room ${layout.roomId}';
  }

  String _surfaceTitleForLayout(PlasterSurfaceLayout layout) {
    final roomName = _roomNameForLayout(layout);
    final prefix = '$roomName ';
    return layout.label.startsWith(prefix)
        ? layout.label.substring(prefix.length)
        : layout.label;
  }

  List<Widget> _buildSheetLayoutCards(List<PlasterSurfaceLayout> layouts) {
    final widgets = <Widget>[];
    int? currentRoomId;

    for (final layout in layouts) {
      if (currentRoomId != layout.roomId) {
        currentRoomId = layout.roomId;
        if (widgets.isNotEmpty) {
          widgets.add(const SizedBox(height: 8));
        }
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              _roomNameForLayout(layout),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        );
      }

      widgets.add(
        Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openLayoutViewer(layout),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 500;
                  final estimatedTape = PlasterGeometry.formatDisplayLength(
                    layout.estimatedJointTapeLength,
                    _unitSystemForLayout(layout),
                  );
                  final details = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_surfaceTitleForLayout(layout)),
                      const SizedBox(height: 4),
                      Text(
                        '${layout.material.name}  '
                        '${layout.sheetsAcross} across x '
                        '${layout.sheetsDown} high',
                      ),
                      Text(layout.direction.layoutLabel),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _DirectionChip(
                            label: 'Auto',
                            selected:
                                _storedDirectionForLayout(layout) ==
                                PlasterSheetDirection.auto,
                            onSelected: () => _setSurfaceDirection(
                              layout,
                              PlasterSheetDirection.auto,
                            ),
                          ),
                          _DirectionChip(
                            label: 'Landscape',
                            selected:
                                _storedDirectionForLayout(layout) ==
                                PlasterSheetDirection.horizontal,
                            onSelected: () => _setSurfaceDirection(
                              layout,
                              PlasterSheetDirection.horizontal,
                            ),
                          ),
                          _DirectionChip(
                            label: 'Portrait',
                            selected:
                                _storedDirectionForLayout(layout) ==
                                PlasterSheetDirection.vertical,
                            onSelected: () => _setSurfaceDirection(
                              layout,
                              PlasterSheetDirection.vertical,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                  final metrics = Column(
                    crossAxisAlignment: narrow
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.end,
                    children: [
                      Text('${layout.sheetCount} sheets'),
                      Text('$estimatedTape tape'),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Open Full Screen Layout',
                            onPressed: () => _openLayoutViewer(layout),
                            icon: const Icon(Icons.open_in_full),
                          ),
                        ],
                      ),
                    ],
                  );

                  if (narrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SurfaceLayoutDiagram(
                              layout: layout,
                              unitSystem: _unitSystemForLayout(layout),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: metrics),
                          ],
                        ),
                        const SizedBox(height: 12),
                        details,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SurfaceLayoutDiagram(
                        layout: layout,
                        unitSystem: _unitSystemForLayout(layout),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: details),
                      const SizedBox(width: 12),
                      metrics,
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildSheetLayoutsSection(List<PlasterSurfaceLayout> layouts) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Sheet Layout',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton.icon(
                onPressed: layouts.isEmpty
                    ? null
                    : () => _openSheetExplorer(layouts),
                icon: const Icon(Icons.account_tree_outlined),
                label: const Text('Sheet Explorer'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildAnalysisStatus(),
          ..._buildSheetLayoutCards(layouts),
        ],
      );

  Widget _buildTakeoffSection(
    PlasterTakeoffSummary takeoff,
    PreferredUnitSystem unitSystem,
  ) {
    final estimatedWasteArea = PlasterGeometry.formatDisplayArea(
      takeoff.estimatedWasteArea,
      unitSystem,
    );
    final estimatedWastage =
        '$estimatedWasteArea '
        '(${takeoff.estimatedWastePercent.toStringAsFixed(1)}%)';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text('Takeoff Summary', style: Theme.of(context).textTheme.titleMedium),
        ListTile(
          title: const Text('Sheets'),
          trailing: Text('${takeoff.totalSheetCount}'),
        ),
        ListTile(
          title: const Text('Sheets incl. waste'),
          trailing: Text(
            '${takeoff.totalSheetCountWithWaste} '
            '(${takeoff.contingencySheetCount} extra)',
          ),
        ),
        ListTile(
          title: const Text('Net surface area'),
          trailing: Text(
            PlasterGeometry.formatDisplayArea(takeoff.surfaceArea, unitSystem),
          ),
        ),
        ListTile(
          title: const Text('Purchased board area'),
          trailing: Text(
            PlasterGeometry.formatDisplayArea(
              takeoff.purchasedBoardArea,
              unitSystem,
            ),
          ),
        ),
        ListTile(
          title: const Text('Estimated wastage'),
          trailing: Text(estimatedWastage),
        ),
        ListTile(
          title: const Text('Cut/layout waste'),
          trailing: Text(
            PlasterGeometry.formatDisplayArea(takeoff.cutWasteArea, unitSystem),
          ),
        ),
        ListTile(
          title: const Text('Contingency waste'),
          trailing: Text(
            PlasterGeometry.formatDisplayArea(
              takeoff.contingencyWasteArea,
              unitSystem,
            ),
          ),
        ),
        ListTile(
          title: const Text('Reusable offcuts'),
          trailing: Text(
            PlasterGeometry.formatDisplayArea(
              takeoff.reusableOffcutArea,
              unitSystem,
            ),
          ),
        ),
        ListTile(
          title: const Text('Cornice'),
          trailing: Text(
            PlasterGeometry.formatLinearTakeoffLength(
              takeoff.corniceLength,
              unitSystem,
            ),
          ),
        ),
        ListTile(
          title: const Text('Inside corners'),
          trailing: Text(
            PlasterGeometry.formatLinearTakeoffLength(
              takeoff.insideCornerLength,
              unitSystem,
            ),
          ),
        ),
        ListTile(
          title: const Text('Outside corners'),
          trailing: Text(
            PlasterGeometry.formatLinearTakeoffLength(
              takeoff.outsideCornerLength,
              unitSystem,
            ),
          ),
        ),
        ListTile(
          title: const Text('Tape'),
          trailing: Text(
            PlasterGeometry.formatLinearTakeoffLength(
              takeoff.tapeLength,
              unitSystem,
            ),
          ),
        ),
        ListTile(
          title: const Text('Screws'),
          trailing: Text('${takeoff.screwCount}'),
        ),
        ListTile(
          title: const Text('Stud adhesive'),
          trailing: Text('${_formatKg(takeoff.glueKg)} kg'),
        ),
        ListTile(
          title: const Text('Joint compound'),
          trailing: Text('${_formatKg(takeoff.plasterKg)} kg'),
        ),
        ListTile(
          title: const Text('Cornice cement'),
          trailing: Text('${_formatKg(takeoff.corniceCementKg)} kg'),
        ),
      ],
    );
  }

  Widget _buildAnalysisStatus() {
    final status = _isAnalyzing
        ? 'Analyzing layout'
        : _analysisElapsedMs == 0
        ? 'Ready to analyze layout'
        : _analysisTimedOut
        ? 'Best layout from timed analysis'
        : _analysisReachedTargetWaste
        ? 'Target waste reached'
        : 'Layout search exhausted';
    final wasteText = _bestWastePercentSeen == null
        ? 'Best waste: n/a'
        : 'Best waste: ${_bestWastePercentSeen!.toStringAsFixed(1)}%';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        child: ListTile(
          dense: true,
          leading: _isAnalyzing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.analytics_outlined),
          title: Text(status),
          subtitle: Text(
            '$wasteText'
            '  •  Elapsed ${(_analysisElapsedMs / 1000).toStringAsFixed(1)}s'
            '  •  Explored $_analysisExploredStates layouts',
          ),
          trailing: _isAnalyzing
              ? TextButton(
                  onPressed: () => unawaited(_stopAnalysis()),
                  child: const Text('Stop'),
                )
              : TextButton(
                  onPressed: () => unawaited(_reanalyzeLayout()),
                  child: const Text('Redo Analysis'),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => DeferredBuilder(
    this,
    builder: (context) {
      final media = MediaQuery.of(context);
      final isMobileLandscape =
          media.orientation == Orientation.landscape &&
          media.size.shortestSide < 700;
      final displayUnit = _rooms.isNotEmpty
          ? _currentRoom.room.unitSystem
          : PreferredUnitSystem.metric;
      return Scaffold(
        appBar: AppBar(
          title: Text(
            _isRoomEditorOnly && _rooms.isNotEmpty
                ? _currentRoom.room.name
                : _project.name,
          ),
          actions: [
            if (_isRoomEditorOnly && _rooms.isNotEmpty)
              IconButton(
                onPressed: () => unawaited(_openEditorFramingSettings()),
                icon: const Icon(Icons.tune),
                tooltip: 'Room framing settings',
              ),
            if (!_isRoomEditorOnly) ...[
              IconButton(
                onPressed: () => unawaited(_saveProject()),
                icon: const Icon(Icons.save),
              ),
              IconButton(
                onPressed: () => unawaited(_previewPdf()),
                icon: const Icon(Icons.picture_as_pdf),
              ),
            ],
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: _isRoomEditorOnly
                ? _buildRoomEditorSection(isMobileLandscape)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Project Name',
                        ),
                        onSubmitted: (_) => unawaited(_saveProject()),
                      ),
                      HMBSelectJob(
                        selectedJob: _selectedJob,
                        required: true,
                        onSelected: (job) async {
                          _job = job;
                          _selectedTask.taskId = null;
                          await _saveProject();
                          setState(() {});
                        },
                      ),
                      HMBSelectTask(
                        selectedTask: _selectedTask,
                        job: _job,
                        onSelected: (task) async {
                          _task = task;
                          await _saveProject();
                        },
                      ),
                      HMBSelectSupplier(
                        selectedSupplier: _selectedSupplier,
                        onSelected: (supplier) async {
                          await _updateSelectedSupplier(supplier);
                        },
                      ),
                      TextField(
                        controller: _wasteController,
                        decoration: const InputDecoration(
                          labelText: 'Waste Allowance %',
                        ),
                        keyboardType: TextInputType.number,
                        onSubmitted: (_) => unawaited(_saveProject()),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _wallStudSpacingController,
                        decoration: InputDecoration(
                          labelText:
                              'Default Wall Stud Spacing '
                              '(${PlasterGeometry.unitLabel(displayUnit)})',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onSubmitted: (_) => unawaited(_saveProject()),
                      ),
                      TextField(
                        controller: _wallStudOffsetController,
                        decoration: InputDecoration(
                          labelText:
                              'Default Wall Stud Offset '
                              '(${PlasterGeometry.unitLabel(displayUnit)})',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onSubmitted: (_) => unawaited(_saveProject()),
                      ),
                      TextField(
                        controller: _wallFixingFaceWidthController,
                        decoration: InputDecoration(
                          labelText:
                              'Default Wall Fixing Face Width '
                              '(${PlasterGeometry.unitLabel(displayUnit)})',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onSubmitted: (_) => unawaited(_saveProject()),
                      ),
                      TextField(
                        controller: _ceilingFramingSpacingController,
                        decoration: InputDecoration(
                          labelText:
                              'Default Ceiling Framing Spacing '
                              '(${PlasterGeometry.unitLabel(displayUnit)})',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onSubmitted: (_) => unawaited(_saveProject()),
                      ),
                      TextField(
                        controller: _ceilingFramingOffsetController,
                        decoration: InputDecoration(
                          labelText:
                              'Default Ceiling Framing Offset '
                              '(${PlasterGeometry.unitLabel(displayUnit)})',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onSubmitted: (_) => unawaited(_saveProject()),
                      ),
                      TextField(
                        controller: _ceilingFixingFaceWidthController,
                        decoration: InputDecoration(
                          labelText:
                              'Default Ceiling Fixing Face Width '
                              '(${PlasterGeometry.unitLabel(displayUnit)})',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onSubmitted: (_) => unawaited(_saveProject()),
                      ),
                      const SizedBox(height: 12),
                      HMBChildCrudCard(
                        headline: 'Rooms',
                        crudListScreen: PlasterRoomListScreen(
                          parent: Parent(_project),
                        ),
                      ),
                      HMBChildCrudCard(
                        headline: 'Material Sizes',
                        crudListScreen: PlasterMaterialSizeListScreen(
                          parent: Parent(_project),
                        ),
                      ),
                      const Divider(),
                      _buildSheetLayoutsSection(_layouts),
                      _buildTakeoffSection(_takeoff, displayUnit),
                    ],
                  ),
          ),
        ),
      );
    },
  );
}

class _RoomBundle {
  PlasterRoom room;
  List<PlasterRoomLine> lines;
  List<PlasterRoomOpening> openings;
  List<PlasterRoomConstraint> constraints;

  _RoomBundle({
    required this.room,
    required this.lines,
    required this.openings,
    required this.constraints,
  });

  _RoomBundle copyWith({
    PlasterRoom? room,
    List<PlasterRoomLine>? lines,
    List<PlasterRoomOpening>? openings,
    List<PlasterRoomConstraint>? constraints,
  }) => _RoomBundle(
    room: room ?? this.room,
    lines: lines ?? this.lines,
    openings: openings ?? this.openings,
    constraints: constraints ?? this.constraints,
  );

  _RoomBundle deepCopy() => _RoomBundle(
    room: room.copyWith(),
    lines: [for (final line in lines) line.copyWith()],
    openings: [for (final opening in openings) opening.copyWith()],
    constraints: [for (final constraint in constraints) constraint.copyWith()],
  );
}

class _DirectionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _DirectionChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onSelected(),
  );
}

class _SurfaceLayoutDiagram extends StatelessWidget {
  final PlasterSurfaceLayout layout;
  final PreferredUnitSystem unitSystem;
  final double width;
  final double height;
  final bool showSheetMeasurements;
  final List<String> sheetNumbers;
  final bool showDimensionsOverlay;

  const _SurfaceLayoutDiagram({
    required this.layout,
    required this.unitSystem,
    this.width = 132,
    this.height = 84,
    this.showSheetMeasurements = false,
    this.sheetNumbers = const <String>[],
    this.showDimensionsOverlay = true,
  });

  @override
  Widget build(BuildContext context) {
    final widthLabel = PlasterGeometry.formatDisplayLength(
      layout.width,
      unitSystem,
    );
    final heightLabel = PlasterGeometry.formatDisplayLength(
      layout.height,
      unitSystem,
    );
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(8),
      ),
      child: CustomPaint(
        painter: _SurfaceLayoutDiagramPainter(
          layout: layout,
          unitSystem: unitSystem,
          showSheetMeasurements: showSheetMeasurements,
          sheetNumbers: sheetNumbers,
        ),
        child: showDimensionsOverlay
            ? Center(
                child: Text(
                  'w: $widthLabel\nh: $heightLabel',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10),
                ),
              )
            : null,
      ),
    );
  }
}

class _SurfaceLayoutDiagramPainter extends CustomPainter {
  final PlasterSurfaceLayout layout;
  final PreferredUnitSystem unitSystem;
  final bool showSheetMeasurements;
  final List<String> sheetNumbers;

  const _SurfaceLayoutDiagramPainter({
    required this.layout,
    required this.unitSystem,
    required this.showSheetMeasurements,
    this.sheetNumbers = const <String>[],
  });

  @override
  void paint(Canvas canvas, Size size) {
    final border = Paint()
      ..color = const Color(0xFF2D8CFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final fill = Paint()
      ..color = const Color(0x221DC8FF)
      ..style = PaintingStyle.fill;
    final sheet = Paint()
      ..color = const Color(0x4439FFB5)
      ..style = PaintingStyle.fill;
    final sheetBorder = Paint()
      ..color = const Color(0xFF39FFB5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final scale = min(size.width / layout.width, size.height / layout.height);
    final scaledWidth = layout.width * scale;
    final scaledHeight = layout.height * scale;
    final offset = Offset(
      (size.width - scaledWidth) / 2,
      (size.height - scaledHeight) / 2,
    );
    final rect = offset & Size(scaledWidth, scaledHeight);
    canvas.drawRect(rect, fill);
    for (var i = 0; i < layout.placements.length; i++) {
      final placement = layout.placements[i];
      final sheetRect = Rect.fromLTWH(
        offset.dx + placement.x * scale,
        offset.dy + placement.y * scale,
        placement.width * scale,
        placement.height * scale,
      );
      canvas
        ..drawRect(sheetRect, sheet)
        ..drawRect(sheetRect, sheetBorder);
      if (i < sheetNumbers.length) {
        _paintSheetNumberBadge(canvas, sheetRect, sheetNumbers[i]);
      }
      if (showSheetMeasurements) {
        final pieceWidth = PlasterGeometry.formatDisplayLength(
          placement.width,
          unitSystem,
        );
        final pieceHeight = PlasterGeometry.formatDisplayLength(
          placement.height,
          unitSystem,
        );
        _paintSheetDimensions(canvas, sheetRect, '$pieceWidth\n$pieceHeight');
      }
    }
    canvas.drawRect(rect, border);
  }

  void _paintSheetNumberBadge(Canvas canvas, Rect rect, String text) {
    if (rect.width < 18 || rect.height < 18) {
      return;
    }
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 7,
          fontWeight: FontWeight.w600,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: rect.width - 6);
    final badge = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        rect.left + 4,
        rect.top + 4,
        textPainter.width + 8,
        textPainter.height + 6,
      ),
      const Radius.circular(10),
    );
    canvas.drawRRect(badge, Paint()..color = const Color(0xDD111827));
    textPainter.paint(
      canvas,
      Offset(
        badge.left + (badge.width - textPainter.width) / 2,
        badge.top + (badge.height - textPainter.height) / 2,
      ),
    );
  }

  void _paintSheetDimensions(Canvas canvas, Rect rect, String text) {
    if (rect.width < 54 || rect.height < 26) {
      return;
    }
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout(maxWidth: rect.width - 8);
    final background = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: rect.center,
        width: textPainter.width + 8,
        height: textPainter.height + 6,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(background, Paint()..color = const Color(0xBB111827));
    textPainter.paint(
      canvas,
      Offset(
        rect.center.dx - textPainter.width / 2,
        rect.center.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _SurfaceLayoutDiagramPainter oldDelegate) =>
      oldDelegate.layout != layout ||
      oldDelegate.unitSystem != unitSystem ||
      oldDelegate.showSheetMeasurements != showSheetMeasurements ||
      oldDelegate.sheetNumbers != sheetNumbers;
}

class _ProjectSheetExplorerScreen extends StatelessWidget {
  final List<PlasterProjectSheet> sheets;
  final List<PlasterSurfaceLayout> layouts;

  const _ProjectSheetExplorerScreen({
    required this.sheets,
    required this.layouts,
  });

  @override
  Widget build(BuildContext context) {
    final orderedLayouts = [...layouts]
      ..sort((left, right) {
        if (left.isCeiling != right.isCeiling) {
          return left.isCeiling ? -1 : 1;
        }
        final roomCompare = left.roomId.compareTo(right.roomId);
        if (roomCompare != 0) {
          return roomCompare;
        }
        return left.label.compareTo(right.label);
      });

    return Scaffold(
      appBar: AppBar(title: const Text('Sheet Explorer')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _ProjectSheetLegend(),
          const SizedBox(height: 16),
          for (final layout in orderedLayouts) ...[
            Text(
              layout.isCeiling ? 'Ceiling' : 'Wall',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final layoutSheets = [
                  for (final sheet in sheets)
                    if (sheet.usedPieces.any(
                      (piece) => piece.surfaceLabel == layout.label,
                    ))
                      sheet,
                ];
                final labels = _ExplorerSheetLabels(layoutSheets);
                final sheetNumbers = [
                  for (final sheet in layoutSheets) labels.sheetLabel(sheet),
                ];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SurfaceSheetExplorerSection(
                      layout: layout,
                      sheetNumbers: sheetNumbers,
                    ),
                    const SizedBox(height: 12),
                    if (layoutSheets.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(left: 8, bottom: 8),
                        child: Text('No sheets assigned.'),
                      )
                    else
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final sheet in layoutSheets)
                            _ProjectSheetCard(
                              sheet: sheet,
                              layout: layout,
                              labels: labels,
                            ),
                        ],
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}

class _ProjectSheetLegend extends StatelessWidget {
  const _ProjectSheetLegend();

  @override
  Widget build(BuildContext context) => const Wrap(
    spacing: 12,
    runSpacing: 8,
    children: [
      _LegendChip(label: 'Fresh sheet piece', color: Color(0xFF4DD8B0)),
      _LegendChip(label: 'Reused offcut piece', color: Color(0xFF8B5CF6)),
      _LegendChip(
        label: 'Reusable offcut not reused',
        color: Color(0xFF4A90E2),
      ),
      _LegendChip(
        label: 'Reusable offcut reused later',
        color: Color(0xFF0EA5A8),
      ),
      _LegendChip(label: 'Scrap', color: Color(0xFFE67E22)),
    ],
  );
}

class _ExplorerSheetLabels {
  final Map<int, String> _sheetLabelsByNumber;
  final Map<String, String> _subsheetLabelsByPair;

  factory _ExplorerSheetLabels(List<PlasterProjectSheet> sheets) {
    final sheetLabelsByNumber = <int, String>{};
    for (var i = 0; i < sheets.length; i++) {
      sheetLabelsByNumber[sheets[i].sheetNumber] = '${i + 1}';
    }

    final nextBranchIndexBySource = <int, int>{};
    final subsheetLabelsByPair = <String, String>{};
    for (final sheet in sheets) {
      final sourceSheets = <int>{
        for (final piece in sheet.usedPieces)
          if (piece.reusedOffcut && piece.sourceSheetNumber != null)
            piece.sourceSheetNumber!,
      }.toList()..sort();
      for (final sourceSheet in sourceSheets) {
        final pairKey = '$sourceSheet:${sheet.sheetNumber}';
        final branchIndex = nextBranchIndexBySource.update(
          sourceSheet,
          (current) => current + 1,
          ifAbsent: () => 1,
        );
        final sourceLabel = sheetLabelsByNumber[sourceSheet] ?? '$sourceSheet';
        subsheetLabelsByPair[pairKey] = '$sourceLabel.$branchIndex';
      }
    }

    return _ExplorerSheetLabels._(sheetLabelsByNumber, subsheetLabelsByPair);
  }

  const _ExplorerSheetLabels._(
    this._sheetLabelsByNumber,
    this._subsheetLabelsByPair,
  );

  String sheetLabel(PlasterProjectSheet sheet) =>
      _sheetLabelsByNumber[sheet.sheetNumber] ?? '${sheet.sheetNumber}';

  String? subsheetLabelForPiece(
    PlasterProjectSheet sheet,
    PlasterProjectSheetPiece piece,
  ) {
    if (!piece.reusedOffcut || piece.sourceSheetNumber == null) {
      return null;
    }
    final pairKey = '${piece.sourceSheetNumber}:${sheet.sheetNumber}';
    return _subsheetLabelsByPair[pairKey];
  }
}

class _SurfaceSheetExplorerSection extends StatelessWidget {
  final PlasterSurfaceLayout layout;
  final List<String> sheetNumbers;

  const _SurfaceSheetExplorerSection({
    required this.layout,
    required this.sheetNumbers,
  });

  void _openZoom(BuildContext context) {
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _SurfaceLayoutViewerScreen(
            layout: layout,
            unitSystem: layout.material.unitSystem,
            sheetNumbers: sheetNumbers,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SurfaceLayoutDiagram(
            layout: layout,
            unitSystem: layout.material.unitSystem,
            width: 112,
            height: 72,
            sheetNumbers: sheetNumbers,
            showDimensionsOverlay: false,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  layout.label,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '${layout.material.name}  '
                  '${layout.sheetsAcross} across x ${layout.sheetsDown} high',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(layout.direction.layoutLabel),
                const SizedBox(height: 6),
                Text(
                  sheetNumbers.isEmpty
                      ? 'Sheets: none'
                      : 'Sheets: ${sheetNumbers.join(', ')}',
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => _openZoom(context),
                    icon: const Icon(Icons.zoom_out_map),
                    label: const Text('Zoom'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _LegendChip extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.white24),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    ),
  );
}

class _ProjectSheetCard extends StatelessWidget {
  final PlasterProjectSheet sheet;
  final PlasterSurfaceLayout layout;
  final _ExplorerSheetLabels labels;

  const _ProjectSheetCard({
    required this.sheet,
    required this.layout,
    required this.labels,
  });

  String _formatLength(int value) =>
      PlasterGeometry.formatDisplayLength(value, sheet.material.unitSystem);

  String _formatArea(int area) =>
      PlasterGeometry.formatDisplayArea(area, sheet.material.unitSystem);

  String _formatPiece(PlasterProjectSheetPiece piece) {
    final sourceLabel = labels.subsheetLabelForPiece(sheet, piece);
    final sourceSuffix = sourceLabel == null ? '' : ' from $sourceLabel';
    return 'width ${_formatLength(piece.width)} x '
        'length ${_formatLength(piece.height)}'
        '${piece.reusedOffcut ? ' reused offcut' : ' fresh'}'
        '$sourceSuffix';
  }

  bool get _rotateForLayout {
    final stockLandscape = sheet.sheetWidth >= sheet.sheetHeight;
    final targetLandscape = switch (layout.direction) {
      PlasterSheetDirection.horizontal => true,
      PlasterSheetDirection.vertical => false,
      PlasterSheetDirection.auto => stockLandscape,
    };
    return targetLandscape != stockLandscape;
  }

  @override
  Widget build(BuildContext context) {
    final rotateForLayout = _rotateForLayout;
    final displayWidth = rotateForLayout ? sheet.sheetHeight : sheet.sheetWidth;
    final displayHeight = rotateForLayout
        ? sheet.sheetWidth
        : sheet.sheetHeight;
    final reusableOffcuts = [
      for (final offcut in sheet.offcuts)
        if (offcut.reusable) offcut,
    ];
    final reusableArea = reusableOffcuts.fold<int>(
      0,
      (sum, offcut) => sum + offcut.area,
    );
    final scrapArea = sheet.offcuts.fold<int>(
      0,
      (sum, offcut) => sum + (offcut.reusable ? 0 : offcut.area),
    );
    final reusedLaterCount = reusableOffcuts
        .where((offcut) => offcut.reusedLater)
        .length;
    final reusedLaterArea = reusableOffcuts.fold<int>(
      0,
      (sum, offcut) => sum + (offcut.reusedLater ? offcut.area : 0),
    );
    final neverReusedCount = reusableOffcuts.length - reusedLaterCount;
    final neverReusedArea = reusableArea - reusedLaterArea;
    final relevantPieces = [
      for (final piece in sheet.usedPieces)
        if (piece.surfaceLabel == layout.label) piece,
    ];
    final reusedCount = relevantPieces
        .where((piece) => piece.reusedOffcut)
        .length;
    final freshCount = relevantPieces.length - reusedCount;
    final pieceDetails = [
      for (final piece in relevantPieces) _formatPiece(piece),
    ];

    return Container(
      width: 280,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sheet ${labels.sheetLabel(sheet)}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(
            'Width ${_formatLength(displayWidth)} x '
            'Length ${_formatLength(displayHeight)}',
            style: const TextStyle(fontSize: 11),
          ),
          const SizedBox(height: 8),
          _ProjectSheetDiagram(
            sheet: sheet,
            layout: layout,
            rotateForLayout: rotateForLayout,
            formatLength: _formatLength,
            labels: labels,
          ),
          const SizedBox(height: 8),
          Text('Fresh pieces: $freshCount'),
          Text('Reused-offcut pieces: $reusedCount'),
          Text('Reusable offcuts: ${_formatArea(reusableArea)}'),
          Text(
            'Reused later: '
            '$reusedLaterCount (${_formatArea(reusedLaterArea)})',
          ),
          Text(
            'Not reused: '
            '$neverReusedCount (${_formatArea(neverReusedArea)})',
          ),
          Text('Scrap: ${_formatArea(scrapArea)}'),
          if (pieceDetails.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (var i = 0; i < pieceDetails.length; i++)
              Text(
                'Piece ${i + 1}: ${pieceDetails[i]}',
                style: const TextStyle(fontSize: 11),
              ),
          ],
        ],
      ),
    );
  }
}

class _ProjectSheetDiagram extends StatelessWidget {
  final PlasterProjectSheet sheet;
  final PlasterSurfaceLayout layout;
  final bool rotateForLayout;
  final String Function(int value) formatLength;
  final _ExplorerSheetLabels labels;

  const _ProjectSheetDiagram({
    required this.sheet,
    required this.layout,
    required this.rotateForLayout,
    required this.formatLength,
    required this.labels,
  });

  Future<void> _showPieceDetails(
    BuildContext context,
    PlasterProjectSheetPiece piece,
  ) async {
    final sourceLabel = labels.subsheetLabelForPiece(sheet, piece);
    final sourceSheetLine = sourceLabel == null
        ? ''
        : '\nFrom Sheet $sourceLabel';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Sheet ${labels.sheetLabel(sheet)} Piece'),
        content: Text(
          'Width ${formatLength(piece.width)} x '
          'Length ${formatLength(piece.height)}\n'
          '${piece.reusedOffcut ? 'Reused offcut piece' : 'Fresh piece'}'
          '$sourceSheetLine',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showOffcutDetails(
    BuildContext context,
    PlasterSheetOffcut offcut,
  ) async {
    final type = offcut.reusable
        ? (offcut.reusedLater
              ? 'Reusable offcut reused later'
              : 'Reusable offcut not reused')
        : 'Scrap';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Sheet ${labels.sheetLabel(sheet)} Offcut'),
        content: Text(
          'Width ${formatLength(offcut.width)} x '
          'Length ${formatLength(offcut.height)}\n'
          '$type',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _handleTap(BuildContext context, TapUpDetails details) {
    final relevantPieces = [
      for (final piece in sheet.usedPieces)
        if (piece.surfaceLabel == layout.label) piece,
    ];
    final metrics = _ProjectSheetDiagramMetrics.fromSize(
      sheet: sheet,
      rotateForLayout: rotateForLayout,
      size: const Size(260, 160),
    );
    const hitSlop = 8.0;

    for (final piece in relevantPieces.reversed) {
      if (metrics
          .sheetRectToCanvas(piece.x, piece.y, piece.width, piece.height)
          .inflate(hitSlop)
          .contains(details.localPosition)) {
        unawaited(_showPieceDetails(context, piece));
        return;
      }
    }

    for (final offcut in sheet.offcuts.reversed) {
      if (metrics
          .sheetRectToCanvas(offcut.x, offcut.y, offcut.width, offcut.height)
          .inflate(hitSlop)
          .contains(details.localPosition)) {
        unawaited(_showOffcutDetails(context, offcut));
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapUp: (details) => _handleTap(context, details),
    child: SizedBox(
      width: 260,
      height: 160,
      child: CustomPaint(
        painter: _ProjectSheetExplorerPainter(
          sheet: sheet,
          rotateForLayout: rotateForLayout,
          currentLayoutLabel: layout.label,
          formatLength: formatLength,
          labels: labels,
        ),
      ),
    ),
  );
}

class _ProjectSheetDiagramMetrics {
  final PlasterProjectSheet sheet;
  final bool rotateForLayout;
  final double scale;
  final Offset offset;

  const _ProjectSheetDiagramMetrics({
    required this.sheet,
    required this.rotateForLayout,
    required this.scale,
    required this.offset,
  });

  factory _ProjectSheetDiagramMetrics.fromSize({
    required PlasterProjectSheet sheet,
    required bool rotateForLayout,
    required Size size,
  }) {
    final displaySheetWidth = rotateForLayout
        ? sheet.sheetHeight
        : sheet.sheetWidth;
    final displaySheetHeight = rotateForLayout
        ? sheet.sheetWidth
        : sheet.sheetHeight;
    final scale = min(
      size.width / displaySheetWidth,
      size.height / displaySheetHeight,
    );
    final scaledWidth = displaySheetWidth * scale;
    final scaledHeight = displaySheetHeight * scale;
    final offset = Offset(
      (size.width - scaledWidth) / 2,
      (size.height - scaledHeight) / 2,
    );
    return _ProjectSheetDiagramMetrics(
      sheet: sheet,
      rotateForLayout: rotateForLayout,
      scale: scale,
      offset: offset,
    );
  }

  Rect get bounds =>
      offset &
      Size(
        (rotateForLayout ? sheet.sheetHeight : sheet.sheetWidth) * scale,
        (rotateForLayout ? sheet.sheetWidth : sheet.sheetHeight) * scale,
      );

  Rect sheetRectToCanvas(int x, int y, int width, int height) {
    if (!rotateForLayout) {
      return Rect.fromLTWH(
        offset.dx + x * scale,
        offset.dy + y * scale,
        width * scale,
        height * scale,
      );
    }

    return Rect.fromLTWH(
      offset.dx + (sheet.sheetHeight - y - height) * scale,
      offset.dy + x * scale,
      height * scale,
      width * scale,
    );
  }
}

class _ProjectSheetExplorerPainter extends CustomPainter {
  final PlasterProjectSheet sheet;
  final bool rotateForLayout;
  final String currentLayoutLabel;
  final String Function(int value) formatLength;
  final _ExplorerSheetLabels labels;

  const _ProjectSheetExplorerPainter({
    required this.sheet,
    required this.rotateForLayout,
    required this.currentLayoutLabel,
    required this.formatLength,
    required this.labels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final border = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final background = Paint()
      ..color = Colors.white.withSafeOpacity(0.04)
      ..style = PaintingStyle.fill;
    final freshPaint = Paint()..color = const Color(0xFF4DD8B0);
    final reusedPaint = Paint()..color = const Color(0xFF8B5CF6);
    final unusedOffcutPaint = Paint()..color = const Color(0xFF4A90E2);
    final reusedLaterOffcutPaint = Paint()..color = const Color(0xFF0EA5A8);
    final scrapPaint = Paint()..color = const Color(0xFFE67E22);
    final metrics = _ProjectSheetDiagramMetrics.fromSize(
      sheet: sheet,
      rotateForLayout: rotateForLayout,
      size: size,
    );
    final rect = metrics.bounds;
    canvas.drawRect(rect, background);

    for (final piece in sheet.usedPieces) {
      final pieceRect = metrics.sheetRectToCanvas(
        piece.x,
        piece.y,
        piece.width,
        piece.height,
      );
      canvas.drawRect(pieceRect, piece.reusedOffcut ? reusedPaint : freshPaint);
      if (piece.reusedOffcut) {
        final subsheetLabel = labels.subsheetLabelForPiece(sheet, piece);
        if (subsheetLabel != null) {
          _paintPieceBadge(canvas, pieceRect, subsheetLabel);
        }
      }
      if (piece.surfaceLabel == currentLayoutLabel) {
        _paintLabel(
          canvas,
          pieceRect,
          '${formatLength(piece.width)}\n${formatLength(piece.height)}',
        );
      }
    }

    for (final offcut in sheet.offcuts) {
      final offcutRect = metrics.sheetRectToCanvas(
        offcut.x,
        offcut.y,
        offcut.width,
        offcut.height,
      );
      canvas.drawRect(
        offcutRect,
        offcut.reusable
            ? (offcut.reusedLater ? reusedLaterOffcutPaint : unusedOffcutPaint)
            : scrapPaint,
      );
    }

    canvas.drawRect(rect, border);
  }

  void _paintPieceBadge(Canvas canvas, Rect rect, String text) {
    if (rect.width < 26 || rect.height < 18) {
      return;
    }
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 7,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: rect.width - 8);
    final badge = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        rect.left + 4,
        rect.top + 4,
        painter.width + 8,
        painter.height + 6,
      ),
      const Radius.circular(10),
    );
    canvas.drawRRect(badge, Paint()..color = const Color(0xDD111827));
    painter.paint(
      canvas,
      Offset(
        badge.left + (badge.width - painter.width) / 2,
        badge.top + (badge.height - painter.height) / 2,
      ),
    );
  }

  void _paintLabel(Canvas canvas, Rect rect, String text) {
    if (rect.width < 48 || rect.height < 24) {
      return;
    }
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 3,
      ellipsis: '…',
    )..layout(maxWidth: rect.width - 8);
    final bg = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: rect.center,
        width: min(rect.width - 4, painter.width + 8),
        height: painter.height + 6,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(bg, Paint()..color = const Color(0xBB111827));
    painter.paint(
      canvas,
      Offset(
        bg.left + (bg.width - painter.width) / 2,
        bg.top + (bg.height - painter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _ProjectSheetExplorerPainter oldDelegate) =>
      oldDelegate.sheet != sheet ||
      oldDelegate.rotateForLayout != rotateForLayout ||
      oldDelegate.currentLayoutLabel != currentLayoutLabel ||
      oldDelegate.labels != labels;
}

class _SurfaceLayoutViewerScreen extends StatelessWidget {
  final PlasterSurfaceLayout layout;
  final PreferredUnitSystem unitSystem;
  final List<String> sheetNumbers;

  const _SurfaceLayoutViewerScreen({
    required this.layout,
    required this.unitSystem,
    this.sheetNumbers = const <String>[],
  });

  @override
  Widget build(BuildContext context) {
    final widthLabel = PlasterGeometry.formatDisplayLength(
      layout.width,
      unitSystem,
    );
    final heightLabel = PlasterGeometry.formatDisplayLength(
      layout.height,
      unitSystem,
    );
    final materialDirectionLabel =
        '${layout.material.name}  ${layout.direction.layoutLabel}';
    return Scaffold(
      appBar: AppBar(title: Text(layout.label)),
      body: OrientationBuilder(
        builder: (context, orientation) {
          final rotateQuarterTurns =
              orientation == Orientation.landscape &&
                  layout.height > layout.width
              ? 1
              : 0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      materialDirectionLabel,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'w: $widthLabel x h: $heightLabel'
                      '  •  ${layout.sheetCount} sheets',
                    ),
                    const Text('Tap-drag to pan, pinch to zoom.'),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final diagramWidth = rotateQuarterTurns == 0
                        ? constraints.maxWidth - 32
                        : constraints.maxHeight - 32;
                    final diagramHeight = rotateQuarterTurns == 0
                        ? constraints.maxHeight - 32
                        : constraints.maxWidth - 32;
                    final diagram = Center(
                      child: RotatedBox(
                        quarterTurns: rotateQuarterTurns,
                        child: _SurfaceLayoutDiagram(
                          layout: layout,
                          unitSystem: unitSystem,
                          width: max(240, diagramWidth),
                          height: max(240, diagramHeight),
                          showSheetMeasurements: true,
                          sheetNumbers: sheetNumbers,
                          showDimensionsOverlay: false,
                        ),
                      ),
                    );
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 6,
                        boundaryMargin: const EdgeInsets.all(64),
                        child: diagram,
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LengthDialog extends StatefulWidget {
  final PreferredUnitSystem unitSystem;
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
      text: widget.unitSystem == PreferredUnitSystem.metric
          ? PlasterGeometry.formatDisplayLength(
              widget.initialValue,
              widget.unitSystem,
            ).replaceFirst(RegExp(r'\s+mm$'), '')
          : '',
    );
    final totalInches =
        widget.initialValue / PlasterGeometry.imperialUnitsPerInch;
    final feet = totalInches ~/ PlasterGeometry.inchesPerFoot;
    final inches = totalInches - feet * PlasterGeometry.inchesPerFoot;
    _feetController = TextEditingController(
      text: widget.unitSystem == PreferredUnitSystem.imperial
          ? feet.toString()
          : '',
    );
    _inchesController = TextEditingController(
      text: widget.unitSystem == PreferredUnitSystem.imperial
          ? _formatInches(inches)
          : '',
    );
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _focusNode.requestFocus();
      final controller = widget.unitSystem == PreferredUnitSystem.metric
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
    if (widget.unitSystem == PreferredUnitSystem.metric) {
      return PlasterGeometry.parseDisplayLength(
        _metricController.text,
        widget.unitSystem,
      );
    }

    final feet = int.tryParse(_feetController.text.trim()) ?? 0;
    final inches = double.tryParse(_inchesController.text.trim()) ?? 0;
    if (feet == 0 && inches == 0) {
      return null;
    }

    final totalInches = feet * PlasterGeometry.inchesPerFoot + inches;
    return (totalInches * PlasterGeometry.imperialUnitsPerInch).round();
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
    content: widget.unitSystem == PreferredUnitSystem.metric
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
  final int lineId;
  final PreferredUnitSystem unitSystem;
  final PlasterOpeningType type;
  final PlasterRoomOpening? initialOpening;
  final String title;
  final String confirmLabel;

  const _OpeningDialog({
    required this.lineId,
    required this.unitSystem,
    required this.type,
    this.initialOpening,
    String? title,
    String? confirmLabel,
  }) : title =
           title ??
           (type == PlasterOpeningType.door ? 'Add Door' : 'Add Window'),
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
      _width.text = PlasterGeometry.formatDisplayLength(
        initialOpening.width,
        widget.unitSystem,
      ).replaceFirst(RegExp(r'\s+[A-Za-z/"]+$'), '');
      _height.text = PlasterGeometry.formatDisplayLength(
        initialOpening.height,
        widget.unitSystem,
      ).replaceFirst(RegExp(r'\s+[A-Za-z/"]+$'), '');
      _sill.text = PlasterGeometry.formatDisplayLength(
        initialOpening.sillHeight,
        widget.unitSystem,
      ).replaceFirst(RegExp(r'\s+[A-Za-z/"]+$'), '');
    } else if (widget.unitSystem == PreferredUnitSystem.metric) {
      _width.text = widget.type == PlasterOpeningType.door ? '820' : '1200';
      _height.text = widget.type == PlasterOpeningType.door ? '2040' : '1200';
      _sill.text = widget.type == PlasterOpeningType.window ? '900' : '0';
    } else {
      _width.text = widget.type == PlasterOpeningType.door
          ? '2\' 8"'
          : '4\' 0"';
      _height.text = widget.type == PlasterOpeningType.door
          ? '6\' 8"'
          : '4\' 0"';
      _sill.text = widget.type == PlasterOpeningType.window
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
                'Width (${PlasterGeometry.unitLabel(widget.unitSystem)})',
          ),
        ),
        TextField(
          controller: _height,
          keyboardType: TextInputType.text,
          decoration: InputDecoration(
            labelText:
                'Height (${PlasterGeometry.unitLabel(widget.unitSystem)})',
          ),
        ),
        if (widget.type == PlasterOpeningType.window)
          TextField(
            controller: _sill,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              labelText: '''
Sill Height (${PlasterGeometry.unitLabel(widget.unitSystem)})''',
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
          final width = PlasterGeometry.parseDisplayLength(
            _width.text,
            widget.unitSystem,
          );
          final height = PlasterGeometry.parseDisplayLength(
            _height.text,
            widget.unitSystem,
          );
          final sill =
              PlasterGeometry.parseDisplayLength(
                _sill.text,
                widget.unitSystem,
              ) ??
              0;
          if (width == null || height == null) {
            return;
          }
          Navigator.of(context).pop(
            widget.initialOpening?.copyWith(
                  width: width,
                  height: height,
                  sillHeight: sill,
                ) ??
                PlasterRoomOpening.forInsert(
                  lineId: widget.lineId,
                  type: widget.type,
                  offsetFromStart: 0,
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
