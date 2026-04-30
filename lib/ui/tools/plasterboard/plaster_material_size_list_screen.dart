/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.
*/

import 'package:flutter/material.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../../util/dart/plaster_geometry.dart';
import '../../crud/base_nested/list_nested_screen.dart';
import 'plaster_material_size_edit_screen.dart';

class PlasterMaterialSizeListScreen extends StatelessWidget {
  final Parent<PlasterProject> parent;

  const PlasterMaterialSizeListScreen({required this.parent, super.key});

  @override
  Widget build(BuildContext context) {
    final project = parent.parent;
    if (project == null || project.supplierId == null) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          'Select a supplier on the project before managing shared '
          'plasterboard sizes.',
        ),
      );
    }

    return NestedEntityListScreen<PlasterMaterialSize, PlasterProject>(
      parent: parent,
      parentTitle: 'project',
      entityNamePlural: 'Material Sizes',
      entityNameSingular: 'Material Size',
      dao: DaoPlasterMaterialSize(),
      fetchList: () =>
          DaoPlasterMaterialSize().getBySupplier(project.supplierId!),
      extended: true,
      title: (material) => Text(material.name),
      onEdit: (material) =>
          PlasterMaterialSizeEditScreen(project: project, material: material),
      onDelete: (material) => DaoPlasterMaterialSize().delete(material.id),
      cardHeight: 116,
      details: (material, cardDetail) => LayoutBuilder(
        builder: (context, constraints) {
          final widthLabel = PlasterGeometry.formatDisplayLength(
            material.width,
            material.unitSystem,
          );
          final lengthLabel = PlasterGeometry.formatDisplayLength(
            material.height,
            material.unitSystem,
          );
          final widthText = Text('Width: $widthLabel');
          final lengthText = Text('Length: $lengthLabel');
          final statusText = Text(
            material.excludedFromLayout
                ? 'Excluded from layout'
                : 'Available for layout',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: material.excludedFromLayout
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.onSurface,
            ),
          );

          if (constraints.maxWidth < 420) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                widthText,
                const SizedBox(height: 4),
                lengthText,
                const SizedBox(height: 4),
                statusText,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: widthText),
              const SizedBox(width: 12),
              Expanded(child: lengthText),
              const SizedBox(width: 12),
              Expanded(child: statusText),
            ],
          );
        },
      ),
    );
  }
}
