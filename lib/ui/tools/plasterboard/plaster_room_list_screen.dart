/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.
*/

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../../dao/dao.g.dart';
import '../../../dao/notification/dao_june_builder.dart';
import '../../../entity/entity.g.dart';
import '../../../util/dart/plaster_geometry.dart';
import '../../crud/base_nested/list_nested_screen.dart';
import '../../widgets/layout/layout.g.dart';
import 'plaster_project_screen.dart';
import 'plaster_room_edit_screen.dart';
import 'plaster_room_preview.dart';

class PlasterRoomListScreen extends StatelessWidget {
  final Parent<PlasterProject> parent;

  const PlasterRoomListScreen({
    required this.parent,
    super.key,
  });

  @override
  Widget build(BuildContext context) => NestedEntityListScreen<
    PlasterRoom,
    PlasterProject
  >(
    parent: parent,
    parentTitle: 'project',
    entityNamePlural: 'Rooms',
    entityNameSingular: 'Room',
    dao: DaoPlasterRoom(),
    fetchList: () => DaoPlasterRoom().getByProject(parent.parent!.id),
    title: (room) => Text(room.name),
    onEdit: (room) =>
        PlasterRoomEditScreen(project: parent.parent!, room: room),
    onDelete: (room) => DaoPlasterRoom().delete(room.id),
    extended: true,
    cardHeight: 190,
    details: (room, cardDetail) => DaoJuneBuilder.builder(
      DaoPlasterRoomLine(),
      builder: (context) => FutureBuilderEx<_RoomPreviewData>(
        future: _loadPreview(room),
        builder: (context, data) {
          final preview = data!;
          Future<void> openDiagramEditor() async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PlasterProjectScreen(
                  project: parent.parent,
                  editorOnlyRoomId: room.id,
                ),
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final wideLayout = constraints.maxWidth >= 560;
              final previewWidth = wideLayout
                  ? constraints.maxWidth * 0.58
                  : constraints.maxWidth;
              final previewHeight = wideLayout ? 112.0 : 96.0;
              final summaryStyle = Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1);
              final summary = DefaultTextStyle(
                style: summaryStyle ?? const TextStyle(height: 1),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ceiling Height: '
                      '${PlasterGeometry.formatDisplayLength(
                        room.ceilingHeight,
                        room.unitSystem,
                      )}',
                    ),
                    Text('Walls: ${preview.lines.length}'),
                    Text('Openings: ${preview.openings.length}'),
                  ],
                ),
              );

              if (!wideLayout) {
                return HMBColumn(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: openDiagramEditor,
                      borderRadius: BorderRadius.circular(8),
                      child: PlasterRoomPreview(
                        room: room,
                        lines: preview.lines,
                        width: previewWidth,
                        height: previewHeight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    summary,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: openDiagramEditor,
                    borderRadius: BorderRadius.circular(8),
                    child: PlasterRoomPreview(
                      room: room,
                      lines: preview.lines,
                      width: previewWidth,
                      height: previewHeight,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: summary),
                ],
              );
            },
          );
        },
      ),
    ),
  );

  Future<_RoomPreviewData> _loadPreview(PlasterRoom room) async {
    final lines = await DaoPlasterRoomLine().getByRoom(room.id);
    final openings = lines.isEmpty
        ? <PlasterRoomOpening>[]
        : await DaoPlasterRoomOpening().getByLineIds(
            lines.map((line) => line.id).toList(),
          );
    return _RoomPreviewData(lines: lines, openings: openings);
  }
}

class _RoomPreviewData {
  final List<PlasterRoomLine> lines;
  final List<PlasterRoomOpening> openings;

  const _RoomPreviewData({
    required this.lines,
    required this.openings,
  });
}
