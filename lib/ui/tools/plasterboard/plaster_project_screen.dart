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
import '../../../util/dart/app_settings.dart';
import '../../../util/dart/measurement_type.dart';
import '../../../util/dart/plaster_constraint_solver.dart';
import '../../../util/dart/plaster_geometry.dart';
import '../../../util/dart/plaster_sheet_direction.dart';
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
  final _ceilingFramingSpacingController = TextEditingController();
  final _ceilingFramingOffsetController = TextEditingController();
  final _lineStudSpacingController = TextEditingController();
  final _lineStudOffsetController = TextEditingController();
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
      _selectedJob.jobId = project.jobId;
      _selectedTask.taskId = project.taskId;
      _selectedSupplier.selected = project.supplierId;
      _hasLoadedProjectState = true;
    });
    _syncRoomControllers();
    unawaited(_startAnalysis());
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
    _ceilingFramingSpacingController.dispose();
    _ceilingFramingOffsetController.dispose();
    _lineStudSpacingController.dispose();
    _lineStudOffsetController.dispose();
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
        ScaffoldMessenger.of(context).showSnackBar(
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
    if ((spacingText.isNotEmpty && spacing == null) ||
        (offsetText.isNotEmpty && offset == null)) {
      _syncRoomControllers();
      if (mounted) {
        setState(() {});
      }
      return;
    }
    if (currentLine.studSpacingOverride == spacing &&
        currentLine.studOffsetOverride == offset) {
      return;
    }
    final lines = List<PlasterRoomLine>.from(_currentRoom.lines);
    lines[_selectedLineIndex!] = currentLine.copyWith(
      studSpacingOverride: spacing,
      studOffsetOverride: offset,
    );
    await _updateCurrentRoom(
      _currentRoom.copyWith(lines: lines),
      trackUndo: false,
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

  Future<void> _showSolveError(PlasterSolveResult result) async {
    if (!mounted) {
      return;
    }
    final violation = result.violations.isEmpty
        ? null
        : result.violations.first;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          violation == null
              ? 'Unable to satisfy all constraints.'
              : _formatSolveViolation(violation),
        ),
      ),
    );
  }

  String _formatSolveViolation(PlasterConstraintViolation violation) {
    final unitSystem = _currentRoom.room.unitSystem;
    final requestedLength = PlasterGeometry.formatDisplayLength(
      violation.constraint.targetValue ?? 0,
      unitSystem,
    );
    return switch (violation.constraint.type) {
      PlasterConstraintType.lineLength =>
        'The requested line length conflicts with existing constraints. '
            'Requested length: $requestedLength.',
      PlasterConstraintType.horizontal =>
        'This line cannot remain horizontal '
            'with the current constraints.',
      PlasterConstraintType.vertical =>
        'This line cannot remain vertical '
            'with the current constraints.',
      PlasterConstraintType.jointAngle =>
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
    final result = PlasterConstraintSolver.solve(
      lines: bundle.lines,
      constraints: bundle.constraints,
      pinnedVertexIndex: pinnedVertexIndex,
      pinnedVertexTarget: pinnedVertexTarget,
    );
    if (!result.converged) {
      if (showError) {
        await _showSolveError(result);
      }
      return;
    }
    final solvedBundle = bundle.copyWith(lines: result.lines);
    if (persist) {
      await _updateCurrentRoom(solvedBundle, trackUndo: trackUndo);
    } else {
      _replaceCurrentRoomLocally(solvedBundle, trackUndo: trackUndo);
    }
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
    final horizontalConstraint = _constraintForLine(
      line.id,
      PlasterConstraintType.horizontal,
    );
    final constraints = horizontalConstraint == null
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
    await _solveAndUpdateRoom(_currentRoom.copyWith(constraints: constraints));
  }

  Future<void> _toggleVerticalConstraint(int index) async {
    final line = _currentRoom.lines[index];
    final verticalConstraint = _constraintForLine(
      line.id,
      PlasterConstraintType.vertical,
    );
    final constraints = verticalConstraint == null
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
    await _solveAndUpdateRoom(_currentRoom.copyWith(constraints: constraints));
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
              PlasterConstraintSolver.currentAngleValue(
                _currentRoom.lines,
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
            PlasterConstraintSolver.currentAngleValue(
              _currentRoom.lines,
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
    final primaryButtons = <Widget>[
      _ToolbarButton(
        icon: _selectionMode ? Icons.touch_app : Icons.ads_click,
        label: _selectionMode ? 'Select Mode' : 'Edit Mode',
        helpText:
            'Toggle between selection mode and direct geometry editing. '
            'Selection mode lets you pick walls, joints, and openings so you '
            'can apply tools to them.',
        selected: _selectionMode,
        onPressed: () => setState(() => _selectionMode = !_selectionMode),
      ),
      _ToolbarButton(
        icon: Icons.undo,
        label: 'Undo',
        helpText:
            'Restore the previous room-editing step, including geometry and '
            'openings.',
        enabled: _undo.isNotEmpty,
        onPressed: () async {
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
      ),
      _ToolbarButton(
        icon: Icons.redo,
        label: 'Redo',
        helpText: 'Reapply the most recently undone room-editing step.',
        enabled: _redo.isNotEmpty,
        onPressed: () async {
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
      ),
      _ToolbarButton(
        icon: Icons.fit_screen,
        label: 'Fit',
        helpText:
            'Reset the drawing zoom and pan so the current room fits back into '
            'view.',
        onPressed: () => setState(() => _fitCanvasRequest++),
      ),
      _ToolbarButton(
        icon: _snapToGrid ? Icons.grid_on : Icons.grid_off,
        label: _snapToGrid ? 'Snap On' : 'Snap Off',
        helpText:
            'Turn grid snapping on or off when moving points and openings.',
        selected: _snapToGrid,
        onPressed: () => setState(() => _snapToGrid = !_snapToGrid),
      ),
      _ToolbarButton(
        icon: _showGrid ? Icons.border_all : Icons.border_clear,
        label: _showGrid ? 'Grid On' : 'Grid Off',
        helpText: 'Show or hide the background drawing grid.',
        selected: _showGrid,
        onPressed: () => setState(() => _showGrid = !_showGrid),
      ),
      _ToolbarButton(
        icon: Icons.deselect,
        label: 'Deselect',
        helpText: 'Clear the current wall, joint, or opening selection.',
        enabled: hasLine || hasIntersection || hasOpening,
        onPressed: () => setState(_clearSelection),
      ),
      _ToolbarButton(
        icon: Icons.content_cut,
        label: 'Split',
        helpText:
            'Split the selected wall into two connected wall segments at its '
            'midpoint.',
        enabled: hasLine,
        onPressed: hasLine ? () => _splitLine(_selectedLineIndex!) : null,
      ),
      _ToolbarButton(
        icon: Icons.door_front_door_outlined,
        label: 'Door',
        helpText: 'Add a door opening to the selected wall.',
        enabled: hasLine,
        onPressed: hasLine
            ? () => _addOpeningToLine(
                _selectedLineIndex!,
                PlasterOpeningType.door,
              )
            : null,
      ),
      _ToolbarButton(
        icon: Icons.web_asset_outlined,
        label: 'Window',
        helpText: 'Add a window opening to the selected wall.',
        enabled: hasLine,
        onPressed: hasLine
            ? () => _addOpeningToLine(
                _selectedLineIndex!,
                PlasterOpeningType.window,
              )
            : null,
      ),
      _ToolbarButton(
        icon: selectedOpening?.type == PlasterOpeningType.door
            ? Icons.door_front_door_outlined
            : Icons.web_asset_outlined,
        label: hasOpening ? 'Edit Opening' : 'Opening',
        helpText: 'Edit the currently selected door or window opening.',
        enabled: hasOpening,
        selected: hasOpening,
        onPressed: hasOpening
            ? () => _editOpening(_selectedOpeningIndex!)
            : null,
      ),
      _ToolbarButton(
        icon: Icons.delete_outline,
        label: 'Delete Opening',
        helpText: 'Remove the currently selected door or window opening.',
        enabled: hasOpening,
        onPressed: hasOpening
            ? () => _deleteOpening(_selectedOpeningIndex!)
            : null,
      ),
      _ToolbarButton(
        icon: isSelectedLinePlaster
            ? Icons.layers_clear_outlined
            : Icons.layers_outlined,
        label: isSelectedLinePlaster ? 'Exclude' : 'Include',
        helpText:
            'Include or exclude the selected wall from plasterboard layout '
            'calculation.',
        enabled: hasLine,
        onPressed: hasLine
            ? () => _toggleLinePlasterSelected(_selectedLineIndex!)
            : null,
      ),
    ];

    final constraintButtons = <Widget>[
      _ToolbarButton(
        icon: Icons.straighten,
        label: hasLineLengthConstraint ? 'Remove Length' : 'Length',
        helpText:
            'Set or remove a fixed length constraint on the selected wall. '
            'This is a wall constraint tool.',
        enabled: hasLine,
        selected: hasLineLengthConstraint,
        onPressed: hasLine
            ? () {
                if (hasLineLengthConstraint) {
                  unawaited(_removeLineLengthConstraint(_selectedLineIndex!));
                } else {
                  unawaited(_editLineLengthConstraint(_selectedLineIndex!));
                }
              }
            : null,
      ),
      _ToolbarButton(
        icon: Icons.horizontal_rule,
        label: hasHorizontalConstraint ? 'Remove Horizontal' : 'Horizontal',
        helpText: 'Set or remove a horizontal constraint on the selected wall.',
        enabled: hasLine,
        selected: hasHorizontalConstraint,
        onPressed: hasLine
            ? () => _toggleHorizontalConstraint(_selectedLineIndex!)
            : null,
      ),
      _ToolbarButton(
        iconWidget: const RotatedBox(
          quarterTurns: 1,
          child: Icon(Icons.horizontal_rule),
        ),
        label: hasVerticalConstraint ? 'Remove Vertical' : 'Vertical',
        helpText: 'Set or remove a vertical constraint on the selected wall.',
        enabled: hasLine,
        selected: hasVerticalConstraint,
        onPressed: hasLine
            ? () => _toggleVerticalConstraint(_selectedLineIndex!)
            : null,
      ),
      _ToolbarButton(
        icon: Icons.polyline,
        label: 'Joint',
        helpText:
            'Open joint actions for the selected corner, including joining '
            'lines and managing joint-angle constraints.',
        enabled: hasIntersection,
        onPressed: hasIntersection
            ? () => _deleteIntersection(_selectedIntersectionIndex!)
            : null,
      ),
      _ToolbarButton(
        icon: Icons.architecture,
        label: hasAngleConstraint ? 'Remove Angle' : 'Angle',
        helpText:
            'Set or remove a fixed angle constraint on the selected joint.',
        enabled: hasIntersection,
        selected: hasAngleConstraint,
        onPressed: hasIntersection
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
    ];

    final toolbarButtons = constraintsOnly
        ? constraintButtons
        : excludeConstraints
        ? primaryButtons
        : [...primaryButtons, ...constraintButtons];

    if (vertical) {
      return SizedBox(
        width: 116,
        child: GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          children: toolbarButtons,
        ),
      );
    }

    if (wrap) {
      return Wrap(spacing: 6, runSpacing: 6, children: toolbarButtons);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final button in toolbarButtons) ...[
            button,
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  Widget _buildRoomCanvas() => _RoomCanvas(
    bundle: _currentRoom,
    selectionMode: _selectionMode,
    snapToGrid: _snapToGrid,
    showGrid: _showGrid,
    fitRequestId: _fitCanvasRequest,
    selectedLineIndex: _selectedLineIndex,
    selectedIntersectionIndex: _selectedIntersectionIndex,
    selectedOpeningIndex: _selectedOpeningIndex,
    onStartMoveIntersection: _beginRoomGestureEdit,
    onMoveIntersection: (index, point) {
      final baseRoom = _gestureBaseRoom ?? _currentRoom;
      final target = _snapToGrid
          ? PlasterGeometry.snapPoint(point, baseRoom.room.unitSystem)
          : point;
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
    onMoveOpening: _moveOpeningLocally,
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
  );

  Widget _buildRoomEditorSection(bool isMobileLandscape) {
    if (_rooms.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Text('This project does not have any rooms yet.'),
      );
    }

    final roomUnitLabel = PlasterGeometry.unitLabel(
      _currentRoom.room.unitSystem,
    );
    final roomFields = LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: ValueKey('room-name-${_currentRoom.room.id}'),
                  controller: _roomNameController,
                  decoration: const InputDecoration(labelText: 'Room Name'),
                  onSubmitted: (_) => unawaited(_commitRoomName()),
                  onEditingComplete: () => unawaited(_commitRoomName()),
                  onTapOutside: (_) => unawaited(_commitRoomName()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<PreferredUnitSystem>(
                  key: ValueKey(
                    'room-unit-'
                    '${_currentRoom.room.id}-'
                    '${_currentRoom.room.unitSystem.name}',
                  ),
                  initialValue: _currentRoom.room.unitSystem,
                  decoration: const InputDecoration(labelText: 'Units'),
                  items: const [
                    DropdownMenuItem(
                      value: PreferredUnitSystem.metric,
                      child: Text('Metric'),
                    ),
                    DropdownMenuItem(
                      value: PreferredUnitSystem.imperial,
                      child: Text('Imperial'),
                    ),
                  ],
                  onChanged: (value) async {
                    if (value == null) {
                      return;
                    }
                    final converted = PlasterGeometry.convertRoomBundle(
                      room: _currentRoom.room,
                      lines: _currentRoom.lines,
                      openings: _currentRoom.openings,
                      target: value,
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
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: ValueKey(
              'ceiling-height-'
              '${_currentRoom.room.id}-'
              '${_currentRoom.room.unitSystem.name}',
            ),
            controller: _ceilingHeightController,
            decoration: InputDecoration(
              labelText:
                  'Ceiling Height '
                  '($roomUnitLabel)',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onSubmitted: (_) => unawaited(_commitCeilingHeight()),
            onEditingComplete: () => unawaited(_commitCeilingHeight()),
            onTapOutside: (_) => unawaited(_commitCeilingHeight()),
          ),
          if (_selectedLineIndex != null) ...[
            const SizedBox(height: 8),
            TextField(
              key: ValueKey(
                'line-stud-spacing-'
                '${_currentRoom.lines[_selectedLineIndex!].id}-'
                '${_currentRoom.room.unitSystem.name}',
              ),
              controller: _lineStudSpacingController,
              decoration: InputDecoration(
                labelText:
                    'Wall Stud Spacing Override '
                    '($roomUnitLabel)',
                helperText: 'Leave blank to use project default.',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onSubmitted: (_) =>
                  unawaited(_commitSelectedLineFramingOverrides()),
              onEditingComplete: () =>
                  unawaited(_commitSelectedLineFramingOverrides()),
              onTapOutside: (_) =>
                  unawaited(_commitSelectedLineFramingOverrides()),
            ),
            const SizedBox(height: 8),
            TextField(
              key: ValueKey(
                'line-stud-offset-'
                '${_currentRoom.lines[_selectedLineIndex!].id}-'
                '${_currentRoom.room.unitSystem.name}',
              ),
              controller: _lineStudOffsetController,
              decoration: InputDecoration(
                labelText:
                    'Wall Stud Offset Override '
                    '($roomUnitLabel)',
                helperText: 'Leave blank to use project default.',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onSubmitted: (_) =>
                  unawaited(_commitSelectedLineFramingOverrides()),
              onEditingComplete: () =>
                  unawaited(_commitSelectedLineFramingOverrides()),
              onTapOutside: (_) =>
                  unawaited(_commitSelectedLineFramingOverrides()),
            ),
          ],
          const SizedBox(height: 8),
          _buildEditorToolbar(wrap: constraints.maxWidth < 520),
          const SizedBox(height: 8),
          _buildRoomCanvas(),
        ],
      ),
    );

    if (isMobileLandscape) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEditorToolbar(vertical: true, excludeConstraints: true),
          const SizedBox(width: 12),
          Expanded(child: _buildRoomCanvas()),
          const SizedBox(width: 12),
          _buildEditorToolbar(vertical: true, constraintsOnly: true),
        ],
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
          Text('Sheet Layout', style: Theme.of(context).textTheme.titleMedium),
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

class _ToolbarButton extends StatelessWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final String label;
  final String helpText;
  final bool enabled;
  final bool selected;
  final VoidCallback? onPressed;

  const _ToolbarButton({
    required this.label,
    required this.helpText,
    this.icon,
    this.iconWidget,
    this.enabled = true,
    this.selected = false,
    this.onPressed,
  }) : assert(
         icon != null || iconWidget != null,
         'Provide either icon or iconWidget.',
       );

  Future<void> _showHelp(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(label),
        content: Text(helpText),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onLongPress: () => unawaited(_showHelp(context)),
    child: IconButton.filledTonal(
      isSelected: selected,
      onPressed: enabled ? onPressed : null,
      icon: iconWidget ?? Icon(icon),
    ),
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

  const _SurfaceLayoutDiagram({
    required this.layout,
    required this.unitSystem,
    this.width = 132,
    this.height = 84,
    this.showSheetMeasurements = false,
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
        ),
        child: Center(
          child: Text(
            'w: $widthLabel\nh: $heightLabel',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10),
          ),
        ),
      ),
    );
  }
}

class _SurfaceLayoutDiagramPainter extends CustomPainter {
  final PlasterSurfaceLayout layout;
  final PreferredUnitSystem unitSystem;
  final bool showSheetMeasurements;

  const _SurfaceLayoutDiagramPainter({
    required this.layout,
    required this.unitSystem,
    required this.showSheetMeasurements,
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
    for (final placement in layout.placements) {
      final sheetRect = Rect.fromLTWH(
        offset.dx + placement.x * scale,
        offset.dy + placement.y * scale,
        placement.width * scale,
        placement.height * scale,
      );
      canvas
        ..drawRect(sheetRect, sheet)
        ..drawRect(sheetRect, sheetBorder);
      if (showSheetMeasurements) {
        final pieceWidth = PlasterGeometry.formatDisplayLength(
          placement.width,
          unitSystem,
        );
        final pieceHeight = PlasterGeometry.formatDisplayLength(
          placement.height,
          unitSystem,
        );
        _paintSheetLabel(canvas, sheetRect, '$pieceWidth\n$pieceHeight');
      }
    }
    canvas.drawRect(rect, border);
  }

  void _paintSheetLabel(Canvas canvas, Rect rect, String text) {
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
      oldDelegate.showSheetMeasurements != showSheetMeasurements;
}

class _SurfaceLayoutViewerScreen extends StatelessWidget {
  final PlasterSurfaceLayout layout;
  final PreferredUnitSystem unitSystem;

  const _SurfaceLayoutViewerScreen({
    required this.layout,
    required this.unitSystem,
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

class _RoomCanvas extends StatefulWidget {
  final _RoomBundle bundle;
  final bool selectionMode;
  final bool snapToGrid;
  final bool showGrid;
  final int fitRequestId;
  final int? selectedLineIndex;
  final int? selectedIntersectionIndex;
  final int? selectedOpeningIndex;
  final VoidCallback onStartMoveIntersection;
  final void Function(int index, IntPoint point) onMoveIntersection;
  final Future<void> Function() onEndMoveIntersection;
  final VoidCallback onStartMoveOpening;
  final void Function(int index, IntPoint point, int anchorOffset)
  onMoveOpening;
  final Future<void> Function() onEndMoveOpening;
  final Future<void> Function(int index) onTapIntersection;
  final Future<void> Function(int index) onTapOpening;
  final Future<void> Function(int index) onTapLine;
  final Future<void> Function() onTapCeiling;

  const _RoomCanvas({
    required this.bundle,
    required this.selectionMode,
    required this.snapToGrid,
    required this.showGrid,
    required this.fitRequestId,
    required this.selectedLineIndex,
    required this.selectedIntersectionIndex,
    required this.selectedOpeningIndex,
    required this.onStartMoveIntersection,
    required this.onMoveIntersection,
    required this.onEndMoveIntersection,
    required this.onStartMoveOpening,
    required this.onMoveOpening,
    required this.onEndMoveOpening,
    required this.onTapIntersection,
    required this.onTapOpening,
    required this.onTapLine,
    required this.onTapCeiling,
  });

  @override
  State<_RoomCanvas> createState() => _RoomCanvasState();
}

class _RoomCanvasState extends State<_RoomCanvas> {
  int? _dragIndex;
  int? _dragOpeningIndex;
  var _dragOpeningAnchorOffset = 0;
  int? _pendingDragIndex;
  int? _pendingDragOpeningIndex;
  var _pendingDragOpeningAnchorOffset = 0;
  int? _gesturePointer;
  Offset? _gestureStartPosition;
  int? _secondaryPanPointer;
  Offset? _secondaryPanPosition;
  var _activePointerCount = 0;
  _CanvasTransform? _dragTransform;
  final _transformationController = TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _RoomCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fitRequestId != widget.fitRequestId) {
      _transformationController.value = Matrix4.identity();
    }
  }

  void _handlePointerSignal(PointerSignalEvent event, Size size) {
    if (event is! PointerScrollEvent) {
      return;
    }

    GestureBinding.instance.pointerSignalResolver.register(event, (
      resolvedEvent,
    ) {
      final scrollEvent = resolvedEvent as PointerScrollEvent;
      final localPosition = scrollEvent.localPosition;
      if (localPosition.dx < 0 ||
          localPosition.dy < 0 ||
          localPosition.dx > size.width ||
          localPosition.dy > size.height) {
        return;
      }

      final currentScale = _transformationController.value.getMaxScaleOnAxis();
      final scaleDelta = exp(-scrollEvent.scrollDelta.dy / 240);
      final nextScale = (currentScale * scaleDelta).clamp(0.5, 4.0);
      final appliedDelta = nextScale / currentScale;
      if (appliedDelta == 1) {
        return;
      }

      final zoomMatrix = Matrix4.identity()
        ..translateByDouble(localPosition.dx, localPosition.dy, 0, 1)
        ..scaleByDouble(appliedDelta, appliedDelta, 1, 1)
        ..translateByDouble(-localPosition.dx, -localPosition.dy, 0, 1);
      _transformationController.value = zoomMatrix.multiplied(
        _transformationController.value,
      );
    });
  }

  bool get _isDraggingGeometry =>
      _dragIndex != null || _dragOpeningIndex != null;

  void _cancelGeometryDrag() {
    final draggingOpening = _dragOpeningIndex != null;
    final draggingIntersection = _dragIndex != null;

    _dragOpeningIndex = null;
    _dragOpeningAnchorOffset = 0;
    _dragIndex = null;
    _clearPendingGesture();

    if (draggingOpening || draggingIntersection) {
      setState(() {});
      if (draggingOpening) {
        unawaited(widget.onEndMoveOpening());
      } else {
        unawaited(widget.onEndMoveIntersection());
      }
    }
  }

  void _clearPendingGesture() {
    _pendingDragIndex = null;
    _pendingDragOpeningIndex = null;
    _pendingDragOpeningAnchorOffset = 0;
    _gesturePointer = null;
    _gestureStartPosition = null;
    _dragTransform = null;
  }

  bool _isSecondaryMousePanEvent(PointerEvent event) =>
      event.kind == PointerDeviceKind.mouse &&
      (event.buttons & kSecondaryMouseButton) != 0;

  void _panCanvas(Offset delta) {
    if (delta == Offset.zero) {
      return;
    }
    final panMatrix = Matrix4.identity()
      ..translateByDouble(delta.dx, delta.dy, 0, 1);
    _transformationController.value = panMatrix.multiplied(
      _transformationController.value,
    );
  }

  void _handlePointerDown(PointerDownEvent event, _CanvasTransform transform) {
    _activePointerCount++;
    if (_isSecondaryMousePanEvent(event)) {
      _cancelGeometryDrag();
      _secondaryPanPointer = event.pointer;
      _secondaryPanPosition = event.localPosition;
      return;
    }
    if (_activePointerCount > 1) {
      _cancelGeometryDrag();
      return;
    }
    if (_isDraggingGeometry) {
      _clearPendingGesture();
      return;
    }

    _gesturePointer = event.pointer;
    _gestureStartPosition = event.localPosition;
    _pendingDragOpeningIndex = transform.hitOpening(
      widget.bundle.openings,
      event.localPosition,
    );
    if (_pendingDragOpeningIndex != null) {
      _dragTransform = transform;
      _pendingDragOpeningAnchorOffset = transform.openingDragAnchorOffset(
        widget.bundle.openings,
        event.localPosition,
        _pendingDragOpeningIndex!,
      );
      _pendingDragIndex = null;
      return;
    }

    _pendingDragIndex = transform.hitIntersection(event.localPosition);
    if (_pendingDragIndex != null) {
      _dragTransform = transform;
    }
  }

  void _handlePointerMove(PointerMoveEvent event, _CanvasTransform transform) {
    if (_secondaryPanPointer == event.pointer &&
        _isSecondaryMousePanEvent(event)) {
      final previous = _secondaryPanPosition;
      if (previous != null) {
        _panCanvas(event.localPosition - previous);
      }
      _secondaryPanPosition = event.localPosition;
      return;
    }

    if (_gesturePointer != event.pointer || _activePointerCount != 1) {
      return;
    }

    final dragTransform = _dragTransform ?? transform;
    if (_dragOpeningIndex != null) {
      widget.onMoveOpening(
        _dragOpeningIndex!,
        dragTransform.toWorld(event.localPosition),
        _dragOpeningAnchorOffset,
      );
      return;
    }
    if (_dragIndex != null) {
      widget.onMoveIntersection(
        _dragIndex!,
        dragTransform.toWorld(event.localPosition),
      );
      return;
    }

    final start = _gestureStartPosition;
    if (start == null || (event.localPosition - start).distance <= 6) {
      return;
    }

    if (_pendingDragOpeningIndex != null) {
      _dragOpeningIndex = _pendingDragOpeningIndex;
      _dragOpeningAnchorOffset = _pendingDragOpeningAnchorOffset;
      widget.onStartMoveOpening();
      setState(() {});
      widget.onMoveOpening(
        _dragOpeningIndex!,
        dragTransform.toWorld(event.localPosition),
        _dragOpeningAnchorOffset,
      );
      return;
    }

    if (_pendingDragIndex != null) {
      _dragIndex = _pendingDragIndex;
      widget.onStartMoveIntersection();
      setState(() {});
      widget.onMoveIntersection(
        _dragIndex!,
        dragTransform.toWorld(event.localPosition),
      );
    }
  }

  void _handlePointerEnd(int pointer) {
    if (_activePointerCount > 0) {
      _activePointerCount--;
    }
    if (_secondaryPanPointer == pointer) {
      _secondaryPanPointer = null;
      _secondaryPanPosition = null;
    }
    if (_gesturePointer != pointer) {
      return;
    }

    final draggingOpening = _dragOpeningIndex != null;
    final draggingIntersection = _dragIndex != null;

    _dragOpeningIndex = null;
    _dragOpeningAnchorOffset = 0;
    _dragIndex = null;
    _clearPendingGesture();

    if (draggingOpening || draggingIntersection) {
      setState(() {});
      if (draggingOpening) {
        unawaited(widget.onEndMoveOpening());
      } else {
        unawaited(widget.onEndMoveIntersection());
      }
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size(constraints.maxWidth, 360);
      if (widget.bundle.lines.isEmpty) {
        return Container(
          height: size.height,
          width: size.width,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'This room has no wall geometry yet. Add or recreate the room '
            'to start drawing.',
            textAlign: TextAlign.center,
          ),
        );
      }
      final transform = _CanvasTransform(widget.bundle.lines, size);
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) => _handlePointerDown(event, transform),
        onPointerMove: (event) => _handlePointerMove(event, transform),
        onPointerUp: (event) => _handlePointerEnd(event.pointer),
        onPointerCancel: (event) => _handlePointerEnd(event.pointer),
        onPointerSignal: (event) => _handlePointerSignal(event, size),
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 0.5,
          maxScale: 4,
          panEnabled: !_isDraggingGeometry,
          scaleEnabled: !_isDraggingGeometry,
          child: GestureDetector(
            onTapUp: (details) async {
              final openingIndex = transform.hitOpening(
                widget.bundle.openings,
                details.localPosition,
              );
              if (openingIndex != null) {
                await widget.onTapOpening(openingIndex);
                return;
              }
              final pointIndex = transform.hitIntersection(
                details.localPosition,
              );
              if (pointIndex != null) {
                await widget.onTapIntersection(pointIndex);
                return;
              }
              final lineIndex = transform.hitLine(details.localPosition);
              if (lineIndex != null) {
                await widget.onTapLine(lineIndex);
                return;
              }
              if (transform.hitPolygon(details.localPosition)) {
                await widget.onTapCeiling();
              }
            },
            child: CustomPaint(
              size: size,
              painter: _RoomPainter(
                bundle: widget.bundle,
                transform: transform,
                selectionMode: widget.selectionMode,
                snapToGrid: widget.snapToGrid,
                showGrid: widget.showGrid,
                selectedLineIndex: widget.selectedLineIndex,
                selectedIntersectionIndex: widget.selectedIntersectionIndex,
                selectedOpeningIndex: widget.selectedOpeningIndex,
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _RoomPainter extends CustomPainter {
  final _RoomBundle bundle;
  final _CanvasTransform transform;
  final bool selectionMode;
  final bool snapToGrid;
  final bool showGrid;
  final int? selectedLineIndex;
  final int? selectedIntersectionIndex;
  final int? selectedOpeningIndex;

  const _RoomPainter({
    required this.bundle,
    required this.transform,
    required this.selectionMode,
    required this.snapToGrid,
    required this.showGrid,
    required this.selectedLineIndex,
    required this.selectedIntersectionIndex,
    required this.selectedOpeningIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintGrid(canvas, size);
    final polygon = Path();
    final lines = bundle.lines;
    if (lines.isEmpty) {
      return;
    }
    final first = transform.toCanvasPoint(
      lines.first.startX,
      lines.first.startY,
    );
    polygon.moveTo(first.dx, first.dy);
    for (var i = 1; i < lines.length; i++) {
      final point = transform.toCanvasPoint(lines[i].startX, lines[i].startY);
      polygon.lineTo(point.dx, point.dy);
    }
    polygon.close();
    final polygonDirection = _polygonDirection(lines);

    final fill = Paint()
      ..color =
          (bundle.room.plasterCeiling
                  ? Colors.blue.withSafeOpacity(0.08)
                  : Colors.grey.withSafeOpacity(0.05))
              .withSafeOpacity(selectionMode ? 0.2 : 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawPath(polygon, fill);

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final start = transform.toCanvasPoint(line.startX, line.startY);
      final endPoint = PlasterGeometry.lineEnd(lines, i);
      final end = transform.toCanvasPoint(endPoint.x, endPoint.y);
      final isSelected = selectedLineIndex == i;
      final isSelectedIntersection = selectedIntersectionIndex == i;
      final paint = Paint()
        ..color = isSelected
            ? Colors.orange
            : (line.plasterSelected ? Colors.blue : Colors.grey)
        ..strokeWidth = isSelected ? 5 : 3;
      final vertexColor = isSelectedIntersection
          ? Colors.redAccent
          : (isSelected
                ? Colors.orange
                : (line.plasterSelected ? Colors.blue : Colors.grey));
      canvas
        ..drawLine(start, end, paint)
        ..drawCircle(
          start,
          isSelected || isSelectedIntersection ? 7 : 6,
          Paint()..color = vertexColor,
        );
      final mid = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
      final dx = end.dx - start.dx;
      final dy = end.dy - start.dy;
      final segmentLength = sqrt(dx * dx + dy * dy);
      final normal = segmentLength == 0
          ? const Offset(0, -1)
          : Offset(-dy / segmentLength, dx / segmentLength);
      final outsideNormal = polygonDirection >= 0 ? -normal : normal;
      final labelText = PlasterGeometry.formatDisplayLength(
        line.length,
        bundle.room.unitSystem,
      );
      final labelPainter = TextPainter(
        text: TextSpan(
          text: labelText,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelOffset =
          mid +
          outsideNormal * 40 -
          Offset(labelPainter.width / 2, labelPainter.height / 2);
      final wallLabelPainter = TextPainter(
        text: TextSpan(
          text: 'W${i + 1}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final wallLabelOffset =
          mid +
          outsideNormal * 20 -
          Offset(wallLabelPainter.width / 2, wallLabelPainter.height / 2);
      final wallLabelBounds = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          wallLabelOffset.dx - 5,
          wallLabelOffset.dy - 2,
          wallLabelPainter.width + 10,
          wallLabelPainter.height + 4,
        ),
        const Radius.circular(8),
      );
      canvas.drawRRect(
        wallLabelBounds,
        Paint()..color = Colors.black.withSafeOpacity(0.8),
      );
      wallLabelPainter.paint(canvas, wallLabelOffset);
      final labelBounds = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          labelOffset.dx - 4,
          labelOffset.dy - 2,
          labelPainter.width + 8,
          labelPainter.height + 4,
        ),
        const Radius.circular(6),
      );
      canvas.drawRRect(
        labelBounds,
        Paint()..color = Colors.white.withSafeOpacity(0.92),
      );
      labelPainter.paint(canvas, labelOffset);
      _paintOpeningsForLine(
        canvas: canvas,
        line: line,
        start: start,
        end: end,
        normal: normal,
        selectedOpeningId: selectedOpeningIndex == null
            ? null
            : bundle.openings[selectedOpeningIndex!].id,
      );
    }
  }

  double _polygonDirection(List<PlasterRoomLine> lines) {
    var area = 0.0;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final end = PlasterGeometry.lineEnd(lines, i);
      area += (line.startX * end.y) - (end.x * line.startY);
    }
    return area;
  }

  void _paintOpeningsForLine({
    required Canvas canvas,
    required PlasterRoomLine line,
    required Offset start,
    required Offset end,
    required Offset normal,
    required int? selectedOpeningId,
  }) {
    final openings = bundle.openings
        .where((opening) => opening.lineId == line.id)
        .toList();
    if (openings.isEmpty) {
      return;
    }

    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final canvasLength = sqrt(dx * dx + dy * dy);
    if (canvasLength == 0 || line.length <= 0) {
      return;
    }

    final direction = Offset(dx / canvasLength, dy / canvasLength);
    final markerOffset = normal * 10;

    for (final opening in openings) {
      final openingStartRatio = opening.offsetFromStart / line.length;
      final openingEndRatio =
          (opening.offsetFromStart + opening.width) / line.length;
      final openingStart =
          start + direction * (canvasLength * openingStartRatio) + markerOffset;
      final openingEnd =
          start + direction * (canvasLength * openingEndRatio) + markerOffset;
      final paint = Paint()
        ..color = opening.id == selectedOpeningId
            ? Colors.orangeAccent
            : opening.type == PlasterOpeningType.door
            ? Colors.brown.shade300
            : Colors.lightBlueAccent
        ..strokeWidth = opening.id == selectedOpeningId ? 8 : 6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(openingStart, openingEnd, paint);

      final markerMid = Offset(
        (openingStart.dx + openingEnd.dx) / 2,
        (openingStart.dy + openingEnd.dy) / 2,
      );
      final markerLabel = opening.type == PlasterOpeningType.door ? 'D' : 'W';
      final labelPainter = TextPainter(
        text: TextSpan(
          text: markerLabel,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final markerRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: markerMid + normal * 14,
          width: labelPainter.width + 10,
          height: labelPainter.height + 6,
        ),
        const Radius.circular(8),
      );
      canvas.drawRRect(
        markerRect,
        Paint()..color = Colors.black.withSafeOpacity(0.75),
      );
      labelPainter.paint(
        canvas,
        Offset(
          markerRect.left + (markerRect.width - labelPainter.width) / 2,
          markerRect.top + (markerRect.height - labelPainter.height) / 2,
        ),
      );
    }
  }

  void _paintGrid(Canvas canvas, Size size) {
    if (!showGrid || bundle.lines.isEmpty) {
      return;
    }
    final gridSize = PlasterGeometry.defaultGridSize(bundle.room.unitSystem);
    final gridPaint = Paint()
      ..color = Colors.grey.withSafeOpacity(0.16)
      ..strokeWidth = 1;
    final startGridX = transform.gridStartX(bundle.room.unitSystem);
    final startGridY = transform.gridStartY(bundle.room.unitSystem);
    final endGridX = transform.gridEndX(bundle.room.unitSystem);
    final endGridY = transform.gridEndY(bundle.room.unitSystem);
    for (var x = startGridX; x <= endGridX; x += gridSize) {
      final canvasX = transform.canvasXForWorldX(x);
      canvas.drawLine(
        Offset(canvasX, 0),
        Offset(canvasX, size.height),
        gridPaint,
      );
    }
    for (var y = startGridY; y <= endGridY; y += gridSize) {
      final canvasY = transform.canvasYForWorldY(y);
      canvas.drawLine(
        Offset(0, canvasY),
        Offset(size.width, canvasY),
        gridPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RoomPainter oldDelegate) =>
      oldDelegate.bundle != bundle ||
      oldDelegate.selectionMode != selectionMode ||
      oldDelegate.snapToGrid != snapToGrid ||
      oldDelegate.showGrid != showGrid ||
      oldDelegate.selectedLineIndex != selectedLineIndex ||
      oldDelegate.selectedIntersectionIndex != selectedIntersectionIndex ||
      oldDelegate.selectedOpeningIndex != selectedOpeningIndex;
}

class _CanvasTransform {
  final List<PlasterRoomLine> lines;
  final Size size;
  late final double _scale;
  late final double _offsetX;
  late final double _offsetY;
  late final int _minX;
  late final int _minY;
  late final int _maxX;
  late final int _maxY;

  _CanvasTransform(this.lines, this.size) {
    final xs = lines.map((line) => line.startX).toList()..sort();
    final ys = lines.map((line) => line.startY).toList()..sort();
    _minX = xs.first;
    _minY = ys.first;
    _maxX = xs.last;
    _maxY = ys.last;
    final width = (_maxX - _minX).abs().toDouble().clamp(1, double.infinity);
    final height = (_maxY - _minY).abs().toDouble().clamp(1, double.infinity);
    _scale = (size.width - 40) / width < (size.height - 40) / height
        ? (size.width - 40) / width
        : (size.height - 40) / height;
    _offsetX = 20;
    _offsetY = 20;
  }

  Offset toCanvasPoint(int x, int y) =>
      Offset(_offsetX + (x - _minX) * _scale, _offsetY + (y - _minY) * _scale);

  double canvasXForWorldX(int x) => _offsetX + (x - _minX) * _scale;

  double canvasYForWorldY(int y) => _offsetY + (y - _minY) * _scale;

  IntPoint toWorld(Offset offset) => IntPoint(
    _minX + ((offset.dx - _offsetX) / _scale).round(),
    _minY + ((offset.dy - _offsetY) / _scale).round(),
  );

  double gridSpacing(PreferredUnitSystem unitSystem) =>
      PlasterGeometry.defaultGridSize(unitSystem) * _scale;

  int gridStartX(PreferredUnitSystem unitSystem) {
    final grid = PlasterGeometry.defaultGridSize(unitSystem);
    return (_minX / grid).floor() * grid;
  }

  int gridStartY(PreferredUnitSystem unitSystem) {
    final grid = PlasterGeometry.defaultGridSize(unitSystem);
    return (_minY / grid).floor() * grid;
  }

  int gridEndX(PreferredUnitSystem unitSystem) {
    final grid = PlasterGeometry.defaultGridSize(unitSystem);
    return (_maxX / grid).ceil() * grid;
  }

  int gridEndY(PreferredUnitSystem unitSystem) {
    final grid = PlasterGeometry.defaultGridSize(unitSystem);
    return (_maxY / grid).ceil() * grid;
  }

  int? hitIntersection(Offset offset) {
    for (var i = 0; i < lines.length; i++) {
      final point = toCanvasPoint(lines[i].startX, lines[i].startY);
      if ((point - offset).distance <= 12) {
        return i;
      }
    }
    return null;
  }

  int? hitLine(Offset offset) {
    for (var i = 0; i < lines.length; i++) {
      final start = toCanvasPoint(lines[i].startX, lines[i].startY);
      final endPoint = PlasterGeometry.lineEnd(lines, i);
      final end = toCanvasPoint(endPoint.x, endPoint.y);
      final distance = _distanceToSegment(offset, start, end);
      if (distance <= 10) {
        return i;
      }
    }
    return null;
  }

  int? hitOpening(List<PlasterRoomOpening> openings, Offset offset) {
    for (var i = 0; i < openings.length; i++) {
      final opening = openings[i];
      final lineIndex = lines.indexWhere((line) => line.id == opening.lineId);
      if (lineIndex < 0) {
        continue;
      }
      final marker = _openingMarker(lines[lineIndex], opening);
      if (marker == null) {
        continue;
      }
      if (marker.contains(offset)) {
        return i;
      }
    }
    return null;
  }

  int openingDragAnchorOffset(
    List<PlasterRoomOpening> openings,
    Offset offset,
    int openingIndex,
  ) {
    if (openingIndex < 0 || openingIndex >= openings.length) {
      return 0;
    }
    final opening = openings[openingIndex];
    final lineIndex = lines.indexWhere((line) => line.id == opening.lineId);
    if (lineIndex < 0) {
      return 0;
    }
    final line = lines[lineIndex];
    final end = PlasterGeometry.lineEnd(lines, lineIndex);
    final dx = end.x - line.startX;
    final dy = end.y - line.startY;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared == 0 || line.length <= 0) {
      return 0;
    }
    final world = toWorld(offset);
    final projected =
        ((world.x - line.startX) * dx + (world.y - line.startY) * dy) /
        lengthSquared;
    final positionOnLine = (projected * line.length).round();
    return (positionOnLine - opening.offsetFromStart).clamp(0, opening.width);
  }

  _OpeningMarker? _openingMarker(
    PlasterRoomLine line,
    PlasterRoomOpening opening,
  ) {
    final lineIndex = lines.indexOf(line);
    if (lineIndex < 0 || line.length <= 0) {
      return null;
    }
    final start = toCanvasPoint(line.startX, line.startY);
    final endPoint = PlasterGeometry.lineEnd(lines, lineIndex);
    final end = toCanvasPoint(endPoint.x, endPoint.y);
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final canvasLength = sqrt(dx * dx + dy * dy);
    if (canvasLength == 0) {
      return null;
    }
    final direction = Offset(dx / canvasLength, dy / canvasLength);
    final normal = Offset(-dy / canvasLength, dx / canvasLength);
    final markerOffset = normal * 10;
    final openingStartRatio = opening.offsetFromStart / line.length;
    final openingEndRatio =
        (opening.offsetFromStart + opening.width) / line.length;
    final openingStart =
        start + direction * (canvasLength * openingStartRatio) + markerOffset;
    final openingEnd =
        start + direction * (canvasLength * openingEndRatio) + markerOffset;
    final markerMid = Offset(
      (openingStart.dx + openingEnd.dx) / 2,
      (openingStart.dy + openingEnd.dy) / 2,
    );
    final badgeCenter = markerMid + normal * 14;
    return _OpeningMarker(
      start: openingStart,
      end: openingEnd,
      badgeHitBox: Rect.fromCircle(center: badgeCenter, radius: 12),
    );
  }

  bool hitPolygon(Offset offset) {
    final path = Path();
    final first = toCanvasPoint(lines.first.startX, lines.first.startY);
    path.moveTo(first.dx, first.dy);
    for (var i = 1; i < lines.length; i++) {
      final point = toCanvasPoint(lines[i].startX, lines[i].startY);
      path.lineTo(point.dx, point.dy);
    }
    path.close();
    return path.contains(offset);
  }

  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    if (dx == 0 && dy == 0) {
      return (p - a).distance;
    }
    final t =
        (((p.dx - a.dx) * dx) + ((p.dy - a.dy) * dy)) / (dx * dx + dy * dy);
    final clamped = t.clamp(0.0, 1.0);
    final projection = Offset(a.dx + dx * clamped, a.dy + dy * clamped);
    return (p - projection).distance;
  }
}

class _OpeningMarker {
  final Offset start;
  final Offset end;
  final Rect badgeHitBox;

  const _OpeningMarker({
    required this.start,
    required this.end,
    required this.badgeHitBox,
  });

  bool contains(Offset point) {
    if (badgeHitBox.contains(point)) {
      return true;
    }
    return _distanceToSegment(point, start, end) <= 6;
  }

  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    if (dx == 0 && dy == 0) {
      return (p - a).distance;
    }
    final t =
        (((p.dx - a.dx) * dx) + ((p.dy - a.dy) * dy)) / (dx * dx + dy * dy);
    final clamped = t.clamp(0.0, 1.0);
    final projection = Offset(a.dx + dx * clamped, a.dy + dy * clamped);
    return (p - projection).distance;
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
      text: PlasterConstraintSolver.angleValueToDegrees(
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
          ).pop(PlasterConstraintSolver.degreesToAngleValue(value));
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
