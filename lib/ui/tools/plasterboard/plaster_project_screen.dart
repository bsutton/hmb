/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.
*/

import 'package:flutter/material.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../../util/dart/measurement_type.dart';
import '../../../util/dart/plaster_geometry.dart';
import '../../dialog/email_dialog.dart';
import '../../widgets/blocking_ui.dart';
import '../../widgets/color_ex.dart';
import '../../widgets/hmb_button.dart';
import '../../widgets/media/pdf_preview.dart';
import '../../widgets/select/hmb_select_job.dart';
import '../../widgets/select/hmb_select_supplier.dart';
import '../../widgets/select/hmb_select_task.dart';
import 'plaster_project_pdf.dart';

class PlasterProjectScreen extends StatefulWidget {
  final PlasterProject? project;

  const PlasterProjectScreen({required this.project, super.key});

  @override
  State<PlasterProjectScreen> createState() => _PlasterProjectScreenState();
}

class _PlasterProjectScreenState extends State<PlasterProjectScreen> {
  final _nameController = TextEditingController();
  final _wasteController = TextEditingController();
  final _ceilingHeightController = TextEditingController();
  final _selectedJob = SelectedJob();
  final _selectedTask = SelectedTask();
  final _selectedSupplier = SelectedSupplier();
  final _undo = <_RoomBundle>[];
  final _redo = <_RoomBundle>[];

  late PlasterProject _project;
  Job? _job;
  Task? _task;
  Supplier? _supplier;
  var _loading = true;
  var _selectionMode = false;
  var _snapToGrid = true;
  var _selectedRoomIndex = 0;
  List<_RoomBundle> _rooms = [];
  List<PlasterMaterialSize> _materials = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final project = widget.project ?? (throw StateError('Project required'));
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
      final lines = await DaoPlasterRoomLine().getByRoom(room.id);
      final openings = await DaoPlasterRoomOpening().getByLineIds(
        lines.map((line) => line.id).toList(),
      );
      bundles.add(_RoomBundle(room: room, lines: lines, openings: openings));
    }
    final materials = await _loadMaterialsForSupplier(project.supplierId);
    if (!mounted) {
      return;
    }
    setState(() {
      _project = project;
      _job = job;
      _task = task;
      _supplier = supplier;
      _rooms = bundles;
      _materials = materials;
      _nameController.text = project.name;
      _wasteController.text = project.wastePercent.toString();
      _selectedJob.jobId = project.jobId;
      _selectedTask.taskId = project.taskId;
      _selectedSupplier.selected = project.supplierId;
      _loading = false;
    });
    _syncRoomControllers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _wasteController.dispose();
    _ceilingHeightController.dispose();
    super.dispose();
  }

  _RoomBundle get _currentRoom => _rooms[_selectedRoomIndex];

  void _syncRoomControllers() {
    if (_rooms.isEmpty) {
      return;
    }
    _ceilingHeightController.text = PlasterGeometry.toDisplay(
      _currentRoom.room.ceilingHeight,
      _currentRoom.room.unitSystem,
    ).toStringAsFixed(2);
  }

  Future<void> _saveProject() async {
    final previousSupplierId = _project.supplierId;
    final updated = _project.copyWith(
      name: _nameController.text.trim().isEmpty
          ? _project.name
          : _nameController.text.trim(),
      jobId: _selectedJob.jobId ?? _project.jobId,
      taskId: _selectedTask.taskId,
      supplierId: _selectedSupplier.selected,
      wastePercent:
          int.tryParse(_wasteController.text.trim()) ?? _project.wastePercent,
    );
    await DaoPlasterProject().update(updated);
    _project = updated;
    _job = await DaoJob().getById(updated.jobId);
    _task = updated.taskId == null
        ? null
        : await DaoTask().getById(updated.taskId);
    _supplier = updated.supplierId == null
        ? null
        : await DaoSupplier().getById(updated.supplierId);
    if (previousSupplierId != updated.supplierId) {
      _materials = await _loadMaterialsForSupplier(updated.supplierId);
    }
    if (mounted) {
      setState(() {});
    }
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
    await DaoPlasterRoom().update(bundle.room);
    bundle.openings = [
      for (final opening in bundle.openings)
        if (bundle.lines.any((line) => line.id == opening.lineId)) opening,
    ];
    final existingLines = await DaoPlasterRoomLine().getByRoom(bundle.room.id);
    final existingLineIds = existingLines.map((line) => line.id).toSet();
    final keptLineIds = <int>{};
    for (var i = 0; i < bundle.lines.length; i++) {
      final line = bundle.lines[i].copyWith(seqNo: i);
      if (line.id < 0) {
        final id = await DaoPlasterRoomLine().insert(line);
        line.id = id;
        bundle.lines[i] = line;
      } else {
        await DaoPlasterRoomLine().update(line);
        bundle.lines[i] = line;
        keptLineIds.add(line.id);
      }
      keptLineIds.add(bundle.lines[i].id);
    }
    for (final line in existingLines.where(
      (line) => !keptLineIds.contains(line.id),
    )) {
      await DaoPlasterRoomLine().delete(line.id);
    }
    final existingOpenings = await DaoPlasterRoomOpening().getByLineIds(
      bundle.lines.map((line) => line.id).toList(),
    );
    final keptOpeningIds = <int>{};
    for (var i = 0; i < bundle.openings.length; i++) {
      final opening = bundle.openings[i];
      if (!bundle.lines.any((line) => line.id == opening.lineId)) {
        continue;
      }
      if (opening.id < 0) {
        final id = await DaoPlasterRoomOpening().insert(opening);
        opening.id = id;
      } else {
        await DaoPlasterRoomOpening().update(opening);
      }
      keptOpeningIds.add(opening.id);
      bundle.openings[i] = opening;
    }
    for (final opening in existingOpenings.where(
      (opening) => !keptOpeningIds.contains(opening.id),
    )) {
      await DaoPlasterRoomOpening().delete(opening.id);
    }
    if (existingLineIds.difference(keptLineIds).isNotEmpty) {
      bundle.openings = await DaoPlasterRoomOpening().getByLineIds(
        bundle.lines.map((line) => line.id).toList(),
      );
    }
  }

  Future<void> _saveMaterials() async {
    final supplierId = _project.supplierId;
    if (supplierId == null) {
      _materials = [];
      return;
    }
    final existing = await DaoPlasterMaterialSize().getBySupplier(supplierId);
    final keptIds = <int>{};
    for (var i = 0; i < _materials.length; i++) {
      final material = _materials[i];
      if (material.id < 0) {
        final id = await DaoPlasterMaterialSize().insert(material);
        material.id = id;
      } else {
        await DaoPlasterMaterialSize().update(material);
      }
      keptIds.add(material.id);
      _materials[i] = material;
    }
    for (final material in existing.where(
      (value) => !keptIds.contains(value.id),
    )) {
      await DaoPlasterMaterialSize().delete(material.id);
    }
  }

  Future<void> _addRoom() async {
    final system = await DaoSystem().get();
    final room = PlasterRoom.forInsert(
      projectId: _project.id,
      name: 'Room ${_rooms.length + 1}',
      unitSystem: system.preferredUnitSystem,
      ceilingHeight: PlasterGeometry.defaultCeilingHeight(
        system.preferredUnitSystem,
      ),
    );
    final roomId = await DaoPlasterRoom().insert(room);
    final savedRoom = (await DaoPlasterRoom().getById(roomId))!;
    final lines = PlasterGeometry.defaultLines(
      roomId: roomId,
      unitSystem: savedRoom.unitSystem,
    );
    final persisted = <PlasterRoomLine>[];
    for (final line in lines) {
      final id = await DaoPlasterRoomLine().insert(line);
      line.id = id;
      persisted.add(line);
    }
    setState(() {
      _rooms.add(_RoomBundle(room: savedRoom, lines: persisted, openings: []));
      _selectedRoomIndex = _rooms.length - 1;
    });
    _syncRoomControllers();
  }

  Future<void> _updateCurrentRoom(
    _RoomBundle bundle, {
    bool trackUndo = true,
  }) async {
    if (trackUndo) {
      _undo.add(_currentRoom.deepCopy());
      _redo.clear();
    }
    _rooms[_selectedRoomIndex] = bundle;
    await _saveRoomBundle(bundle);
    if (mounted) {
      _syncRoomControllers();
      setState(() {});
    }
  }

  Future<void> _previewPdf() async {
    final shapes = _rooms
        .map(
          (bundle) => PlasterRoomShape(
            room: bundle.room,
            lines: bundle.lines,
            openings: bundle.openings,
          ),
        )
        .toList();
    final layouts = PlasterGeometry.calculateLayout(
      shapes,
      _materials,
      int.tryParse(_wasteController.text) ?? _project.wastePercent,
    );
    final file = await BlockingUI().runAndWait(
      label: 'Generating Plasterboard PDF',
      () => generatePlasterProjectPdf(
        project: _project,
        job: _job,
        task: _task,
        supplier: _supplier,
        roomShapes: shapes,
        layouts: layouts,
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

  Future<void> _addMaterialSize() async {
    final supplierId = _project.supplierId;
    if (supplierId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Select a supplier before adding material sizes.'),
          ),
        );
      }
      return;
    }
    final result = await showDialog<PlasterMaterialSize>(
      context: context,
      builder: (_) => _MaterialSizeDialog(supplierId: supplierId),
    );
    if (result == null) {
      return;
    }
    setState(() => _materials.add(result));
    await _saveMaterials();
  }

  Future<void> _lineAction(int index) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Add door'),
              onTap: () => Navigator.of(context).pop('door'),
            ),
            ListTile(
              title: const Text('Add window'),
              onTap: () => Navigator.of(context).pop('window'),
            ),
            ListTile(
              title: const Text('Add left angle'),
              onTap: () => Navigator.of(context).pop('left'),
            ),
            ListTile(
              title: const Text('Add right angle'),
              onTap: () => Navigator.of(context).pop('right'),
            ),
            ListTile(
              title: const Text('Set length'),
              onTap: () => Navigator.of(context).pop('length'),
            ),
            ListTile(
              title: Text(
                _currentRoom.lines[index].plasterSelected
                    ? 'Exclude from plaster'
                    : 'Include in plaster',
              ),
              onTap: () => Navigator.of(context).pop('toggle'),
            ),
          ],
        ),
      ),
    );
    if (selected == null) {
      return;
    }
    if (selected == 'left' || selected == 'right') {
      final lines = PlasterGeometry.insertAngle(
        _currentRoom.lines,
        index,
        leftTurn: selected == 'left',
      );
      await _updateCurrentRoom(_currentRoom.copyWith(lines: lines));
      return;
    }
    if (selected == 'toggle') {
      final lines = List<PlasterRoomLine>.from(_currentRoom.lines);
      final line = lines[index];
      lines[index] = line.copyWith(plasterSelected: !line.plasterSelected);
      await _updateCurrentRoom(_currentRoom.copyWith(lines: lines));
      return;
    }
    if (selected == 'length') {
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
      final lines = PlasterGeometry.setLength(
        _currentRoom.lines,
        index,
        length,
      );
      await _updateCurrentRoom(_currentRoom.copyWith(lines: lines));
      return;
    }

    final opening = await showDialog<PlasterRoomOpening>(
      context: context,
      builder: (_) => _OpeningDialog(
        lineId: _currentRoom.lines[index].id,
        unitSystem: _currentRoom.room.unitSystem,
        type: selected == 'door'
            ? PlasterOpeningType.door
            : PlasterOpeningType.window,
      ),
    );
    if (opening == null) {
      return;
    }
    final lines = PlasterGeometry.ensureLineLength(
      _currentRoom.lines,
      index,
      opening.width,
    );
    final bundle = _currentRoom.copyWith(
      lines: lines,
      openings: [..._currentRoom.openings, opening],
    );
    await _updateCurrentRoom(bundle);
  }

  Future<void> _deleteIntersection(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete angle'),
        content: const Text(
          'Delete this intersection and reconnect the lines?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final lines = PlasterGeometry.deleteIntersection(_currentRoom.lines, index);
    await _updateCurrentRoom(_currentRoom.copyWith(lines: lines));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final layouts = PlasterGeometry.calculateLayout(
      _rooms
          .map(
            (bundle) => PlasterRoomShape(
              room: bundle.room,
              lines: bundle.lines,
              openings: bundle.openings,
            ),
          )
          .toList(),
      _materials,
      int.tryParse(_wasteController.text) ?? _project.wastePercent,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(_project.name),
        actions: [
          IconButton(onPressed: _saveProject, icon: const Icon(Icons.save)),
          IconButton(
            onPressed: _previewPdf,
            icon: const Icon(Icons.picture_as_pdf),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Project Name'),
              onSubmitted: (_) => _saveProject(),
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
                _supplier = supplier;
                await _saveProject();
              },
            ),
            TextField(
              controller: _wasteController,
              decoration: const InputDecoration(labelText: 'Waste %'),
              keyboardType: TextInputType.number,
              onSubmitted: (_) => _saveProject(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Rooms'),
                const SizedBox(width: 8),
                HMBButton.small(
                  label: 'Add Room',
                  hint: 'Add another room',
                  onPressed: _addRoom,
                ),
                const Spacer(),
                HMBButton.small(
                  label: _selectionMode ? 'Edit Mode' : 'Selection Mode',
                  hint: '''
Toggle between editing geometry and selecting plaster surfaces''',
                  onPressed: () =>
                      setState(() => _selectionMode = !_selectionMode),
                ),
                const SizedBox(width: 8),
                HMBButton.small(
                  label: _snapToGrid ? 'Snap On' : 'Snap Off',
                  hint: 'Toggle snapping intersections to the room grid',
                  onPressed: () => setState(() => _snapToGrid = !_snapToGrid),
                ),
              ],
            ),
            if (_rooms.isEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'This project does not have any rooms yet. Add a room to start '
                'drawing walls, openings, and sheet layouts.',
              ),
            ] else ...[
              Wrap(
                spacing: 8,
                children: [
                  for (var i = 0; i < _rooms.length; i++)
                    ChoiceChip(
                      label: Text(_rooms[i].room.name),
                      selected: _selectedRoomIndex == i,
                      onSelected: (_) => setState(() {
                        _selectedRoomIndex = i;
                        _syncRoomControllers();
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: ValueKey('room-name-${_currentRoom.room.id}'),
                      initialValue: _currentRoom.room.name,
                      decoration: const InputDecoration(labelText: 'Room Name'),
                      onFieldSubmitted: (value) async {
                        await _updateCurrentRoom(
                          _currentRoom.copyWith(
                            room: _currentRoom.room.copyWith(
                              name: value.trim(),
                            ),
                          ),
                          trackUndo: false,
                        );
                      },
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
                      '(${PlasterGeometry.unitLabel(_currentRoom.room.unitSystem)})',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onSubmitted: (value) async {
                  final parsed = double.tryParse(value.trim());
                  if (parsed == null) {
                    _syncRoomControllers();
                    setState(() {});
                    return;
                  }
                  await _updateCurrentRoom(
                    _currentRoom.copyWith(
                      room: _currentRoom.room.copyWith(
                        ceilingHeight: PlasterGeometry.fromDisplay(
                          parsed,
                          _currentRoom.room.unitSystem,
                        ),
                      ),
                    ),
                    trackUndo: false,
                  );
                },
              ),
              const SizedBox(height: 8),
              _RoomCanvas(
                bundle: _currentRoom,
                selectionMode: _selectionMode,
                snapToGrid: _snapToGrid,
                onMoveIntersection: (index, point) async {
                  final target = _snapToGrid
                      ? PlasterGeometry.snapPoint(
                          point,
                          _currentRoom.room.unitSystem,
                        )
                      : point;
                  final lines = PlasterGeometry.moveIntersection(
                    _currentRoom.lines,
                    index,
                    target,
                  );
                  await _updateCurrentRoom(_currentRoom.copyWith(lines: lines));
                },
                onTapIntersection: _deleteIntersection,
                onTapLine: (index) async {
                  if (_selectionMode) {
                    final lines = List<PlasterRoomLine>.from(
                      _currentRoom.lines,
                    );
                    final line = lines[index];
                    lines[index] = line.copyWith(
                      plasterSelected: !line.plasterSelected,
                    );
                    await _updateCurrentRoom(
                      _currentRoom.copyWith(lines: lines),
                    );
                  } else {
                    await _lineAction(index);
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
              const SizedBox(height: 8),
              Row(
                children: [
                  HMBButton.small(
                    label: 'Undo',
                    hint: 'Undo the last room edit',
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
                  const SizedBox(width: 8),
                  HMBButton.small(
                    label: 'Redo',
                    hint: 'Redo the last undone room edit',
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
                ],
              ),
            ],
            const Divider(),
            Row(
              children: [
                const Text('Material Sizes'),
                const SizedBox(width: 8),
                HMBButton.small(
                  label: 'Add Size',
                  hint: 'Add another available plasterboard size',
                  onPressed: _addMaterialSize,
                ),
                if (_supplier != null) ...[
                  const SizedBox(width: 8),
                  Text('Supplier: ${_supplier!.name}'),
                ],
              ],
            ),
            if (_supplier == null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Select a supplier to manage reusable plasterboard sizes.',
                ),
              ),
            for (final material in _materials)
              ListTile(
                title: Text(material.name),
                subtitle: Text('''
${PlasterGeometry.toDisplay(material.width, material.unitSystem).toStringAsFixed(2)} 
${PlasterGeometry.unitLabel(material.unitSystem)} x 
${PlasterGeometry.toDisplay(material.height, material.unitSystem).toStringAsFixed(2)} 
${PlasterGeometry.unitLabel(material.unitSystem)}'''),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () async {
                    setState(() => _materials.remove(material));
                    await _saveMaterials();
                  },
                ),
              ),
            const Divider(),
            Text(
              'Sheet Layout',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final layout in layouts)
              ListTile(
                title: Text(layout.label),
                subtitle: Text(
                  '${layout.material.name}  '
                  '${layout.sheetsAcross} x ${layout.sheetsDown}',
                ),
                trailing: Text('${layout.sheetCountWithWaste} sheets'),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoomBundle {
  PlasterRoom room;
  List<PlasterRoomLine> lines;
  List<PlasterRoomOpening> openings;

  _RoomBundle({
    required this.room,
    required this.lines,
    required this.openings,
  });

  _RoomBundle copyWith({
    PlasterRoom? room,
    List<PlasterRoomLine>? lines,
    List<PlasterRoomOpening>? openings,
  }) => _RoomBundle(
    room: room ?? this.room,
    lines: lines ?? this.lines,
    openings: openings ?? this.openings,
  );

  _RoomBundle deepCopy() => _RoomBundle(
    room: room.copyWith(),
    lines: [for (final line in lines) line.copyWith()],
    openings: [for (final opening in openings) opening.copyWith()],
  );
}

class _RoomCanvas extends StatefulWidget {
  final _RoomBundle bundle;
  final bool selectionMode;
  final bool snapToGrid;
  final Future<void> Function(int index, IntPoint point) onMoveIntersection;
  final Future<void> Function(int index) onTapIntersection;
  final Future<void> Function(int index) onTapLine;
  final Future<void> Function() onTapCeiling;

  const _RoomCanvas({
    required this.bundle,
    required this.selectionMode,
    required this.snapToGrid,
    required this.onMoveIntersection,
    required this.onTapIntersection,
    required this.onTapLine,
    required this.onTapCeiling,
  });

  @override
  State<_RoomCanvas> createState() => _RoomCanvasState();
}

class _RoomCanvasState extends State<_RoomCanvas> {
  int? _dragIndex;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size(constraints.maxWidth, 360);
      final transform = _CanvasTransform(widget.bundle.lines, size);
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 4,
        child: GestureDetector(
          onPanStart: (details) {
            final index = transform.hitIntersection(details.localPosition);
            if (index != null) {
              _dragIndex = index;
            }
          },
          onPanUpdate: (details) async {
            if (_dragIndex == null) {
              return;
            }
            final point = transform.toWorld(details.localPosition);
            await widget.onMoveIntersection(_dragIndex!, point);
          },
          onPanEnd: (_) => _dragIndex = null,
          onTapUp: (details) async {
            final pointIndex = transform.hitIntersection(details.localPosition);
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

  const _RoomPainter({
    required this.bundle,
    required this.transform,
    required this.selectionMode,
    required this.snapToGrid,
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

    final fill = Paint()
      ..color =
          (bundle.room.plasterCeiling
                  ? Colors.blue.withSafeOpacity(0.08)
                  : Colors.grey.withSafeOpacity(0.05))
              .withSafeOpacity(selectionMode ? 0.2 : 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawPath(polygon, fill);

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final start = transform.toCanvasPoint(line.startX, line.startY);
      final endPoint = PlasterGeometry.lineEnd(lines, i);
      final end = transform.toCanvasPoint(endPoint.x, endPoint.y);
      final paint = Paint()
        ..color = line.plasterSelected ? Colors.blue : Colors.grey
        ..strokeWidth = 3;
      canvas
        ..drawLine(start, end, paint)
        ..drawCircle(start, 6, Paint()..color = Colors.orange);
      final mid = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
      textPainter
        ..text = TextSpan(
          text: 'W${i + 1}',
          style: const TextStyle(color: Colors.black, fontSize: 12),
        )
        ..layout()
        ..paint(canvas, mid + const Offset(4, -12));
    }
  }

  void _paintGrid(Canvas canvas, Size size) {
    if (!snapToGrid || bundle.lines.isEmpty) {
      return;
    }
    final spacing = transform.gridSpacing(bundle.room.unitSystem);
    final gridPaint = Paint()
      ..color = Colors.grey.withSafeOpacity(0.16)
      ..strokeWidth = 1;
    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RoomPainter oldDelegate) =>
      oldDelegate.bundle != bundle ||
      oldDelegate.selectionMode != selectionMode ||
      oldDelegate.snapToGrid != snapToGrid;
}

class _CanvasTransform {
  final List<PlasterRoomLine> lines;
  final Size size;
  late final double _scale;
  late final double _offsetX;
  late final double _offsetY;
  late final int _minX;
  late final int _minY;

  _CanvasTransform(this.lines, this.size) {
    final xs = lines.map((line) => line.startX).toList()..sort();
    final ys = lines.map((line) => line.startY).toList()..sort();
    _minX = xs.first;
    _minY = ys.first;
    final width = (xs.last - xs.first).abs().toDouble().clamp(
      1,
      double.infinity,
    );
    final height = (ys.last - ys.first).abs().toDouble().clamp(
      1,
      double.infinity,
    );
    _scale = (size.width - 40) / width < (size.height - 40) / height
        ? (size.width - 40) / width
        : (size.height - 40) / height;
    _offsetX = 20;
    _offsetY = 20;
  }

  Offset toCanvasPoint(int x, int y) =>
      Offset(_offsetX + (x - _minX) * _scale, _offsetY + (y - _minY) * _scale);

  IntPoint toWorld(Offset offset) => IntPoint(
    _minX + ((offset.dx - _offsetX) / _scale).round(),
    _minY + ((offset.dy - _offsetY) / _scale).round(),
  );

  double gridSpacing(PreferredUnitSystem unitSystem) =>
      PlasterGeometry.defaultGridSize(unitSystem) * _scale;

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

class _LengthDialog extends StatefulWidget {
  final PreferredUnitSystem unitSystem;
  final int initialValue;

  const _LengthDialog({required this.unitSystem, required this.initialValue});

  @override
  State<_LengthDialog> createState() => _LengthDialogState();
}

class _LengthDialogState extends State<_LengthDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: PlasterGeometry.toDisplay(
        widget.initialValue,
        widget.unitSystem,
      ).toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Set Length'),
    content: TextField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: 'Length (${PlasterGeometry.unitLabel(widget.unitSystem)})',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () {
          final value = double.tryParse(_controller.text.trim());
          if (value == null) {
            return;
          }
          Navigator.of(
            context,
          ).pop(PlasterGeometry.fromDisplay(value, widget.unitSystem));
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

  const _OpeningDialog({
    required this.lineId,
    required this.unitSystem,
    required this.type,
  });

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
    _width.text = widget.type == PlasterOpeningType.door ? '0.82' : '1.20';
    _height.text = widget.type == PlasterOpeningType.door ? '2.04' : '1.20';
    _sill.text = widget.type == PlasterOpeningType.window ? '0.90' : '0.00';
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
    title: Text(
      widget.type == PlasterOpeningType.door ? 'Add Door' : 'Add Window',
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _width,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText:
                'Width (${PlasterGeometry.unitLabel(widget.unitSystem)})',
          ),
        ),
        TextField(
          controller: _height,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText:
                'Height (${PlasterGeometry.unitLabel(widget.unitSystem)})',
          ),
        ),
        if (widget.type == PlasterOpeningType.window)
          TextField(
            controller: _sill,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
          final width = double.tryParse(_width.text.trim());
          final height = double.tryParse(_height.text.trim());
          final sill = double.tryParse(_sill.text.trim()) ?? 0;
          if (width == null || height == null) {
            return;
          }
          Navigator.of(context).pop(
            PlasterRoomOpening.forInsert(
              lineId: widget.lineId,
              type: widget.type,
              offsetFromStart: 0,
              width: PlasterGeometry.fromDisplay(width, widget.unitSystem),
              height: PlasterGeometry.fromDisplay(height, widget.unitSystem),
              sillHeight: PlasterGeometry.fromDisplay(sill, widget.unitSystem),
            ),
          );
        },
        child: const Text('Add'),
      ),
    ],
  );
}

class _MaterialSizeDialog extends StatefulWidget {
  final int supplierId;

  const _MaterialSizeDialog({required this.supplierId});

  @override
  State<_MaterialSizeDialog> createState() => _MaterialSizeDialogState();
}

class _MaterialSizeDialogState extends State<_MaterialSizeDialog> {
  final _name = TextEditingController();
  final _width = TextEditingController();
  final _height = TextEditingController();
  PreferredUnitSystem _unitSystem = PreferredUnitSystem.metric;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add Material Size'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Label'),
        ),
        DropdownButtonFormField<PreferredUnitSystem>(
          initialValue: _unitSystem,
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
          onChanged: (value) => setState(() {
            _unitSystem = value ?? PreferredUnitSystem.metric;
          }),
        ),
        TextField(
          controller: _width,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Width (${PlasterGeometry.unitLabel(_unitSystem)})',
          ),
        ),
        TextField(
          controller: _height,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Height (${PlasterGeometry.unitLabel(_unitSystem)})',
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
          final width = double.tryParse(_width.text.trim());
          final height = double.tryParse(_height.text.trim());
          if (width == null || height == null) {
            return;
          }
          Navigator.of(context).pop(
            PlasterMaterialSize.forInsert(
              supplierId: widget.supplierId,
              name: _name.text.trim().isEmpty
                  ? '${width.toStringAsFixed(2)} x ${height.toStringAsFixed(2)}'
                  : _name.text.trim(),
              unitSystem: _unitSystem,
              width: PlasterGeometry.fromDisplay(width, _unitSystem),
              height: PlasterGeometry.fromDisplay(height, _unitSystem),
            ),
          );
        },
        child: const Text('Add'),
      ),
    ],
  );
}
