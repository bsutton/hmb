/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.
*/

import 'dart:math';

import 'package:flutter/material.dart';

import '../../../entity/plaster_room.dart';
import '../../../entity/plaster_room_line.dart';
import '../../../util/dart/plaster_geometry.dart';

class PlasterRoomPreview extends StatelessWidget {
  final PlasterRoom room;
  final List<PlasterRoomLine> lines;
  final double width;
  final double height;

  const PlasterRoomPreview({
    required this.room,
    required this.lines,
    this.width = 220,
    this.height = 140,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('No diagram'),
      );
    }

    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(8),
      ),
      child: CustomPaint(
        painter: _PlasterRoomPreviewPainter(room: room, lines: lines),
      ),
    );
  }
}

class _PlasterRoomPreviewPainter extends CustomPainter {
  final PlasterRoom room;
  final List<PlasterRoomLine> lines;

  const _PlasterRoomPreviewPainter({
    required this.room,
    required this.lines,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (lines.isEmpty) {
      return;
    }

    var minX = lines.first.startX;
    var maxX = lines.first.startX;
    var minY = lines.first.startY;
    var maxY = lines.first.startY;
    for (var i = 0; i < lines.length; i++) {
      final start = Offset(
        lines[i].startX.toDouble(),
        lines[i].startY.toDouble(),
      );
      final endPoint = PlasterGeometry.lineEnd(lines, i);
      final end = Offset(endPoint.x.toDouble(), endPoint.y.toDouble());
      minX = min(minX, min(start.dx.toInt(), end.dx.toInt()));
      maxX = max(maxX, max(start.dx.toInt(), end.dx.toInt()));
      minY = min(minY, min(start.dy.toInt(), end.dy.toInt()));
      maxY = max(maxY, max(start.dy.toInt(), end.dy.toInt()));
    }

    final shapeWidth = max(1, maxX - minX);
    final shapeHeight = max(1, maxY - minY);
    const padding = 28.0;
    final scale = min(
      (size.width - padding * 2) / shapeWidth,
      (size.height - padding * 2) / shapeHeight,
    );
    final offsetX =
        (size.width - shapeWidth * scale) / 2 - minX * scale;
    final offsetY =
        (size.height - shapeHeight * scale) / 2 - minY * scale;

    Offset toCanvas(int x, int y) =>
        Offset(x * scale + offsetX, y * scale + offsetY);

    final linePaint = Paint()
      ..color = const Color(0xFF2D8CFF)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final vertexPaint = Paint()
      ..color = const Color(0xFF2D8CFF)
      ..style = PaintingStyle.fill;

    final points = <Offset>[];
    for (final line in lines) {
      points.add(toCanvas(line.startX, line.startY));
    }
    final polygon = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      polygon.lineTo(points[i].dx, points[i].dy);
    }
    polygon.close();
    canvas.drawPath(polygon, linePaint);

    for (final point in points) {
      canvas.drawCircle(point, 3, vertexPaint);
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final start = toCanvas(line.startX, line.startY);
      final endPoint = PlasterGeometry.lineEnd(lines, i);
      final end = toCanvas(endPoint.x, endPoint.y);
      final midpoint = Offset(
        (start.dx + end.dx) / 2,
        (start.dy + end.dy) / 2,
      );
      final dx = end.dx - start.dx;
      final dy = end.dy - start.dy;
      final length = sqrt(dx * dx + dy * dy);
      final normal = length == 0
          ? const Offset(0, -1)
          : Offset(dy / length, -dx / length);
      final labelCenter = midpoint + normal * 14;
      final label = PlasterGeometry.formatDisplayLength(
        line.length,
        room.unitSystem,
      );
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width / 2);
      final textOffset = Offset(
        labelCenter.dx - painter.width / 2,
        labelCenter.dy - painter.height / 2,
      );
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          textOffset.dx - 4,
          textOffset.dy - 2,
          painter.width + 8,
          painter.height + 4,
        ),
        const Radius.circular(6),
      );
      canvas.drawRRect(
        rect,
        Paint()..color = const Color(0xCC1E1E1E),
      );
      painter.paint(canvas, textOffset);
    }
  }

  @override
  bool shouldRepaint(covariant _PlasterRoomPreviewPainter oldDelegate) =>
      oldDelegate.room != room || oldDelegate.lines != lines;
}
