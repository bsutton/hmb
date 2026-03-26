/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.
*/

import 'dart:async';

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../../util/dart/measurement_type.dart';
import '../../../util/dart/plaster_geometry.dart';
import '../../widgets/hmb_button.dart';
import 'plaster_project_screen.dart';
import 'plaster_room_preview.dart';

class PlasterRoomEditScreen extends StatefulWidget {
  final PlasterProject project;
  final PlasterRoom? room;

  const PlasterRoomEditScreen({
    required this.project,
    required this.room,
    super.key,
  });

  @override
  State<PlasterRoomEditScreen> createState() => _PlasterRoomEditScreenState();
}

class _PlasterRoomEditScreenState extends DeferredState<PlasterRoomEditScreen> {
  final _nameController = TextEditingController();
  final _ceilingHeightController = TextEditingController();

  late PlasterRoom _room;
  List<PlasterRoomLine> _lines = [];
  List<PlasterRoomOpening> _openings = [];
  String? _error;

  bool get _isNew => widget.room == null;

  @override
  Future<void> asyncInitState() async {
    if (widget.room != null) {
      _room = widget.room!;
      _lines = await DaoPlasterRoomLine().getByRoom(_room.id);
      _openings = _lines.isEmpty
          ? []
          : await DaoPlasterRoomOpening().getByLineIds(
              _lines.map((line) => line.id).toList(),
            );
    } else {
      final system = await DaoSystem().get();
      final rooms = await DaoPlasterRoom().getByProject(widget.project.id);
      _room = PlasterRoom.forInsert(
        projectId: widget.project.id,
        name: 'Room ${rooms.length + 1}',
        unitSystem: system.preferredUnitSystem,
        ceilingHeight: PlasterGeometry.defaultCeilingHeight(
          system.preferredUnitSystem,
        ),
      );
    }
    _syncControllers();
  }

  void _syncControllers() {
    _nameController.text = _room.name;
    _ceilingHeightController.text = PlasterGeometry.formatDisplayLength(
      _room.ceilingHeight,
      _room.unitSystem,
    ).replaceFirst(RegExp(r'\s+[A-Za-z/"]+$'), '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ceilingHeightController.dispose();
    super.dispose();
  }

  Future<PlasterRoom?> _saveRoom() async {
    final name = _nameController.text.trim();
    final ceilingHeight = PlasterGeometry.parseDisplayLength(
      _ceilingHeightController.text,
      _room.unitSystem,
    );
    if (name.isEmpty || ceilingHeight == null || ceilingHeight <= 0) {
      setState(() => _error = 'Enter a room name and valid ceiling height.');
      return null;
    }

    _room = _room.copyWith(name: name, ceilingHeight: ceilingHeight);
    if (_isNew) {
      final id = await DaoPlasterRoom().insert(_room);
      _room.id = id;
      if (_lines.isEmpty) {
        _lines = PlasterGeometry.defaultLines(
          roomId: id,
          unitSystem: _room.unitSystem,
        );
      }
      for (final line in _lines) {
        final persisted = line.copyWith(roomId: id);
        final lineId = await DaoPlasterRoomLine().insert(persisted);
        persisted.id = lineId;
      }
    } else {
      await DaoPlasterRoom().update(_room);
      for (var i = 0; i < _lines.length; i++) {
        await DaoPlasterRoomLine().update(_lines[i]);
      }
      for (var i = 0; i < _openings.length; i++) {
        await DaoPlasterRoomOpening().update(_openings[i]);
      }
    }
    if (!mounted) {
      return _room;
    }
    setState(() => _error = null);
    return _room;
  }

  Future<void> _openDiagramEditor() async {
    final savedRoom = await _saveRoom();
    if (savedRoom == null || !mounted) {
      return;
    }
    final navigator = Navigator.of(context);
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => PlasterProjectScreen(
          project: widget.project,
          editorOnlyRoomId: savedRoom.id,
        ),
      ),
    );
    _room = (await DaoPlasterRoom().getById(savedRoom.id)) ?? savedRoom;
    _lines = await DaoPlasterRoomLine().getByRoom(savedRoom.id);
    _openings = _lines.isEmpty
        ? []
        : await DaoPlasterRoomOpening().getByLineIds(
            _lines.map((line) => line.id).toList(),
          );
    _syncControllers();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _changeUnitSystem(PreferredUnitSystem unitSystem) async {
    if (unitSystem == _room.unitSystem) {
      return;
    }
    final converted = PlasterGeometry.convertRoomBundle(
      room: _room,
      lines: _lines,
      openings: _openings,
      target: unitSystem,
    );
    setState(() {
      _room = converted.$1;
      _lines = converted.$2;
      _openings = converted.$3;
      _syncControllers();
    });
  }

  @override
  Widget build(BuildContext context) => DeferredBuilder(
    this,
    builder: (context) => Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Add Room' : 'Edit Room'),
        actions: [
          IconButton(
            onPressed: () async {
              final room = await _saveRoom();
              if (room != null && mounted) {
                Navigator.of(this.context).pop(room);
              }
            },
            icon: const Icon(Icons.save),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Room Name'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<PreferredUnitSystem>(
            initialValue: _room.unitSystem,
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
            onChanged: (value) {
              if (value != null) {
                unawaited(_changeUnitSystem(value));
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ceilingHeightController,
            decoration: InputDecoration(
              labelText: 'Ceiling Height '
                  '(${PlasterGeometry.unitLabel(_room.unitSystem)})',
            ),
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Room Diagram',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Center(
            child: PlasterRoomPreview(room: _room, lines: _lines),
          ),
          const SizedBox(height: 12),
          HMBButton(
            label: 'Edit Diagram',
            hint: 'Open the full screen diagram editor',
            onPressed: _openDiagramEditor,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
        ],
      ),
    ),
  );
}
