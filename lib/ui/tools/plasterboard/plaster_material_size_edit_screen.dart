/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.
*/

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../../util/dart/measurement_type.dart';
import '../../../util/dart/plaster_geometry.dart';
import 'plaster_attribute_fields.dart';

class PlasterMaterialSizeEditScreen extends StatefulWidget {
  final PlasterProject project;
  final PlasterMaterialSize? material;

  const PlasterMaterialSizeEditScreen({
    required this.project,
    required this.material,
    super.key,
  });

  @override
  State<PlasterMaterialSizeEditScreen> createState() =>
      _PlasterMaterialSizeEditScreenState();
}

class _PlasterMaterialSizeEditScreenState
    extends DeferredState<PlasterMaterialSizeEditScreen> {
  final _nameController = TextEditingController();
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();
  final _thicknessController = TextEditingController();

  late PreferredUnitSystem _unitSystem;
  var _excludedFromLayout = false;
  var _attributeMask = 0;
  int? _supplierId;
  String? _error;

  bool get _isNew => widget.material == null;

  @override
  Future<void> asyncInitState() async {
    final material = widget.material;
    if (material != null) {
      _supplierId = material.supplierId;
      _unitSystem = material.unitSystem;
      _excludedFromLayout = material.excludedFromLayout;
      _attributeMask = material.attributeMask;
      _nameController.text = material.name;
      _widthController.text = PlasterGeometry.formatDisplayLength(
        material.width,
        material.unitSystem,
      ).replaceFirst(RegExp(r'\s+[A-Za-z/"]+$'), '');
      _heightController.text = PlasterGeometry.formatDisplayLength(
        material.height,
        material.unitSystem,
      ).replaceFirst(RegExp(r'\s+[A-Za-z/"]+$'), '');
      _thicknessController.text = PlasterGeometry.formatDisplayLength(
        material.thickness,
        material.unitSystem,
      ).replaceFirst(RegExp(r'\s+[A-Za-z/"]+$'), '');
      return;
    }

    _supplierId = widget.project.supplierId;
    _unitSystem = await _projectUnitSystem();
    _thicknessController.text = PlasterGeometry.formatDisplayLength(
      PlasterGeometry.defaultBoardThickness(_unitSystem),
      _unitSystem,
    ).replaceFirst(RegExp(r'\s+[A-Za-z/"]+$'), '');
  }

  Future<PreferredUnitSystem> _projectUnitSystem() async {
    final rooms = await DaoPlasterRoom().getByProject(widget.project.id);
    if (rooms.isNotEmpty) {
      return rooms.first.unitSystem;
    }
    return (await DaoSystem().get()).preferredUnitSystem;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _thicknessController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final supplierId = _supplierId;
    if (supplierId == null) {
      setState(() {
        _error = 'Select a supplier on the project before adding materials.';
      });
      return;
    }
    final width = PlasterGeometry.parseDisplayLength(
      _widthController.text,
      _unitSystem,
    );
    final height = PlasterGeometry.parseDisplayLength(
      _heightController.text,
      _unitSystem,
    );
    final thickness = PlasterGeometry.parseDisplayLength(
      _thicknessController.text,
      _unitSystem,
    );
    if (width == null ||
        height == null ||
        thickness == null ||
        width <= 0 ||
        height <= 0 ||
        thickness <= 0) {
      setState(() => _error = 'Enter valid material dimensions.');
      return;
    }
    final name = _nameController.text.trim().isEmpty
        ? '${PlasterGeometry.formatDisplayLength(width, _unitSystem)} x '
                  '${PlasterGeometry.formatDisplayLength(height, _unitSystem)}'
              .replaceAll(RegExp(r'\s+(mm|ft|in|")'), '')
        : _nameController.text.trim();

    final material = widget.material == null
        ? PlasterMaterialSize.forInsert(
            supplierId: supplierId,
            name: name,
            unitSystem: _unitSystem,
            width: width,
            height: height,
            thickness: thickness,
            excludedFromLayout: _excludedFromLayout,
            attributeMask: _attributeMask,
          )
        : widget.material!.copyWith(
            supplierId: supplierId,
            name: name,
            unitSystem: _unitSystem,
            width: width,
            height: height,
            thickness: thickness,
            excludedFromLayout: _excludedFromLayout,
            attributeMask: _attributeMask,
          );

    if (_isNew) {
      final id = await DaoPlasterMaterialSize().insert(material);
      material.id = id;
    } else {
      await DaoPlasterMaterialSize().update(material);
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(material);
  }

  @override
  Widget build(BuildContext context) => DeferredBuilder(
    this,
    builder: (context) => Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Add Material Size' : 'Edit Material Size'),
        actions: [IconButton(onPressed: _save, icon: const Icon(Icons.save))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_supplierId == null)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Select a supplier on the project before managing materials.',
              ),
            ),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Material Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _widthController,
            decoration: InputDecoration(
              labelText: 'Width (${PlasterGeometry.unitLabel(_unitSystem)})',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _heightController,
            decoration: InputDecoration(
              labelText: 'Length (${PlasterGeometry.unitLabel(_unitSystem)})',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _thicknessController,
            decoration: InputDecoration(
              labelText:
                  'Thickness (${PlasterGeometry.unitLabel(_unitSystem)})',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          PlasterAttributeFields(
            value: _attributeMask,
            onChanged: (value) => setState(() => _attributeMask = value),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Exclude from layout'),
            subtitle: const Text(
              'Keep this sheet in the supplier material list, but do not use '
              'it when calculating plasterboard layouts.',
            ),
            value: _excludedFromLayout,
            onChanged: (value) {
              setState(() => _excludedFromLayout = value);
            },
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
