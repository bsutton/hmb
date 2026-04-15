import 'dart:async';

import 'package:flutter/material.dart';

import 'room_canvas_models.dart';

class RoomEditorDetailsForm extends StatelessWidget {
  final int roomId;
  final RoomEditorUnitSystem unitSystem;
  final String unitLabel;
  final TextEditingController roomNameController;
  final TextEditingController ceilingHeightController;
  final int? selectedLineId;
  final TextEditingController? lineStudSpacingController;
  final TextEditingController? lineStudOffsetController;
  final ValueChanged<RoomEditorUnitSystem?> onUnitChanged;
  final Future<void> Function() onCommitRoomName;
  final Future<void> Function() onCommitCeilingHeight;
  final Future<void> Function()? onCommitSelectedLineOverrides;
  final Widget editorTools;
  final Widget canvas;

  const RoomEditorDetailsForm({
    required this.roomId,
    required this.unitSystem,
    required this.unitLabel,
    required this.roomNameController,
    required this.ceilingHeightController,
    required this.onUnitChanged,
    required this.onCommitRoomName,
    required this.onCommitCeilingHeight,
    required this.editorTools,
    required this.canvas,
    super.key,
    this.selectedLineId,
    this.lineStudSpacingController,
    this.lineStudOffsetController,
    this.onCommitSelectedLineOverrides,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final media = MediaQuery.of(context);
      final isDesktopLike = constraints.maxWidth >= 1100;
      final wideTopRow = constraints.maxWidth >= 640;
      final canvasHeight = isDesktopLike
          ? (media.size.height * 0.68).clamp(440.0, 820.0)
          : (constraints.maxWidth * 0.72).clamp(
              media.size.shortestSide < 700 ? 320.0 : 360.0,
              560.0,
            );
      final details = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (wideTopRow)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: ValueKey('room-name-$roomId'),
                    controller: roomNameController,
                    decoration: const InputDecoration(labelText: 'Room Name'),
                    onSubmitted: (_) => unawaited(onCommitRoomName()),
                    onEditingComplete: () => unawaited(onCommitRoomName()),
                    onTapOutside: (_) => unawaited(onCommitRoomName()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<RoomEditorUnitSystem>(
                    key: ValueKey('room-unit-$roomId-${unitSystem.name}'),
                    initialValue: unitSystem,
                    decoration: const InputDecoration(labelText: 'Units'),
                    items: const [
                      DropdownMenuItem(
                        value: RoomEditorUnitSystem.metric,
                        child: Text('Metric'),
                      ),
                      DropdownMenuItem(
                        value: RoomEditorUnitSystem.imperial,
                        child: Text('Imperial'),
                      ),
                    ],
                    onChanged: onUnitChanged,
                  ),
                ),
              ],
            )
          else ...[
            TextField(
              key: ValueKey('room-name-$roomId'),
              controller: roomNameController,
              decoration: const InputDecoration(labelText: 'Room Name'),
              onSubmitted: (_) => unawaited(onCommitRoomName()),
              onEditingComplete: () => unawaited(onCommitRoomName()),
              onTapOutside: (_) => unawaited(onCommitRoomName()),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<RoomEditorUnitSystem>(
              key: ValueKey('room-unit-$roomId-${unitSystem.name}'),
              initialValue: unitSystem,
              decoration: const InputDecoration(labelText: 'Units'),
              items: const [
                DropdownMenuItem(
                  value: RoomEditorUnitSystem.metric,
                  child: Text('Metric'),
                ),
                DropdownMenuItem(
                  value: RoomEditorUnitSystem.imperial,
                  child: Text('Imperial'),
                ),
              ],
              onChanged: onUnitChanged,
            ),
          ],
          const SizedBox(height: 8),
          TextField(
            key: ValueKey('ceiling-height-$roomId-${unitSystem.name}'),
            controller: ceilingHeightController,
            decoration: InputDecoration(
              labelText: 'Ceiling Height ($unitLabel)',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onSubmitted: (_) => unawaited(onCommitCeilingHeight()),
            onEditingComplete: () => unawaited(onCommitCeilingHeight()),
            onTapOutside: (_) => unawaited(onCommitCeilingHeight()),
          ),
          if (selectedLineId != null &&
              lineStudSpacingController != null &&
              lineStudOffsetController != null &&
              onCommitSelectedLineOverrides != null) ...[
            const SizedBox(height: 8),
            TextField(
              key: ValueKey(
                'line-stud-spacing-$selectedLineId-${unitSystem.name}',
              ),
              controller: lineStudSpacingController,
              decoration: InputDecoration(
                labelText: 'Wall Stud Spacing Override ($unitLabel)',
                helperText: 'Leave blank to use project default.',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onSubmitted: (_) => unawaited(onCommitSelectedLineOverrides!()),
              onEditingComplete: () =>
                  unawaited(onCommitSelectedLineOverrides!()),
              onTapOutside: (_) => unawaited(onCommitSelectedLineOverrides!()),
            ),
            const SizedBox(height: 8),
            TextField(
              key: ValueKey(
                'line-stud-offset-$selectedLineId-${unitSystem.name}',
              ),
              controller: lineStudOffsetController,
              decoration: InputDecoration(
                labelText: 'Wall Stud Offset Override ($unitLabel)',
                helperText: 'Leave blank to use project default.',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onSubmitted: (_) => unawaited(onCommitSelectedLineOverrides!()),
              onEditingComplete: () =>
                  unawaited(onCommitSelectedLineOverrides!()),
              onTapOutside: (_) => unawaited(onCommitSelectedLineOverrides!()),
            ),
          ],
          const SizedBox(height: 8),
          editorTools,
        ],
      );

      if (isDesktopLike) {
        final detailsWidth = (constraints.maxWidth * 0.3).clamp(320.0, 420.0);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: detailsWidth, child: details),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(height: canvasHeight, child: canvas),
            ),
          ],
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          details,
          const SizedBox(height: 8),
          SizedBox(height: canvasHeight, child: canvas),
        ],
      );
    },
  );
}

class RoomEditorFramingSettingsSheet extends StatelessWidget {
  final String unitLabel;
  final TextEditingController ceilingHeightController;
  final TextEditingController roomCeilingFramingSpacingController;
  final TextEditingController roomCeilingFramingOffsetController;
  final TextEditingController roomCeilingFixingFaceWidthController;
  final bool hasSelectedWall;
  final TextEditingController? lineStudSpacingController;
  final TextEditingController? lineStudOffsetController;
  final TextEditingController? lineFixingFaceWidthController;
  final Future<void> Function() onCommitCeilingHeight;
  final Future<void> Function() onCommitSelectedRoomCeilingOverrides;
  final Future<void> Function()? onCommitSelectedLineOverrides;
  final Future<void> Function() onApply;

  const RoomEditorFramingSettingsSheet({
    required this.unitLabel,
    required this.ceilingHeightController,
    required this.roomCeilingFramingSpacingController,
    required this.roomCeilingFramingOffsetController,
    required this.roomCeilingFixingFaceWidthController,
    required this.hasSelectedWall,
    required this.onCommitCeilingHeight,
    required this.onCommitSelectedRoomCeilingOverrides,
    required this.onApply,
    super.key,
    this.lineStudSpacingController,
    this.lineStudOffsetController,
    this.lineFixingFaceWidthController,
    this.onCommitSelectedLineOverrides,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Room framing settings',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: ceilingHeightController,
          decoration: InputDecoration(labelText: 'Ceiling Height ($unitLabel)'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onSubmitted: (_) => unawaited(onCommitCeilingHeight()),
          onEditingComplete: () => unawaited(onCommitCeilingHeight()),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: roomCeilingFramingSpacingController,
          decoration: InputDecoration(
            labelText: 'Ceiling Framing Spacing Override ($unitLabel)',
            helperText: 'Leave blank to use project default.',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onSubmitted: (_) => unawaited(onCommitSelectedRoomCeilingOverrides()),
          onEditingComplete: () =>
              unawaited(onCommitSelectedRoomCeilingOverrides()),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: roomCeilingFramingOffsetController,
          decoration: InputDecoration(
            labelText: 'Ceiling Framing Offset Override ($unitLabel)',
            helperText: 'Leave blank to use project default.',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onSubmitted: (_) => unawaited(onCommitSelectedRoomCeilingOverrides()),
          onEditingComplete: () =>
              unawaited(onCommitSelectedRoomCeilingOverrides()),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: roomCeilingFixingFaceWidthController,
          decoration: InputDecoration(
            labelText: 'Ceiling Fixing Face Width Override ($unitLabel)',
            helperText: 'Leave blank to use project default.',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onSubmitted: (_) => unawaited(onCommitSelectedRoomCeilingOverrides()),
          onEditingComplete: () =>
              unawaited(onCommitSelectedRoomCeilingOverrides()),
        ),
        if (hasSelectedWall &&
            lineStudSpacingController != null &&
            lineStudOffsetController != null &&
            lineFixingFaceWidthController != null &&
            onCommitSelectedLineOverrides != null) ...[
          const SizedBox(height: 16),
          Text('Selected wall', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: lineStudSpacingController,
            decoration: InputDecoration(
              labelText: 'Wall Stud Spacing Override ($unitLabel)',
              helperText: 'Leave blank to use project default.',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onSubmitted: (_) => unawaited(onCommitSelectedLineOverrides!()),
            onEditingComplete: () =>
                unawaited(onCommitSelectedLineOverrides!()),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: lineStudOffsetController,
            decoration: InputDecoration(
              labelText: 'Wall Stud Offset Override ($unitLabel)',
              helperText: 'Leave blank to use project default.',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onSubmitted: (_) => unawaited(onCommitSelectedLineOverrides!()),
            onEditingComplete: () =>
                unawaited(onCommitSelectedLineOverrides!()),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: lineFixingFaceWidthController,
            decoration: InputDecoration(
              labelText: 'Wall Fixing Face Width Override ($unitLabel)',
              helperText: 'Leave blank to use project default.',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onSubmitted: (_) => unawaited(onCommitSelectedLineOverrides!()),
            onEditingComplete: () =>
                unawaited(onCommitSelectedLineOverrides!()),
          ),
        ],
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: () => unawaited(onApply()),
            child: const Text('Apply'),
          ),
        ),
      ],
    ),
  );
}
