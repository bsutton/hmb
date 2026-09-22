import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/measurement_type.dart';
import 'package:hmb/util/dart/paint_estimate.dart';
import 'package:hmb/util/dart/plaster_geometry.dart';

void main() {
  PlasterRoom room(PreferredUnitSystem unit) => PlasterRoom.forInsert(
    projectId: 1,
    name: 'Room',
    unitSystem: unit,
    ceilingHeight: unit == PreferredUnitSystem.metric ? 24000 : 96000,
    plasterCeiling: false,
  );
  List<PlasterRoomLine> lines(PreferredUnitSystem unit) {
    final result = PlasterGeometry.defaultLines(roomId: 1, unitSystem: unit);
    for (var i = 0; i < result.length; i++) {
      result[i].id = i + 1;
    }
    return result;
  }

  test('uses room dimensions, not sheet selections or installation gaps', () {
    final walls = lines(PreferredUnitSystem.metric);
    walls[0] = walls[0].copyWith(plasterSelected: false);
    final settings = PaintSettings();
    final estimate = PaintEstimate.fromRoom(
      room(PreferredUnitSystem.metric),
      walls,
      [],
      settings,
    );
    expect(estimate.wallArea, closeTo(28.8, 0.00001));
    expect(estimate.ceilingArea, 9);
    expect(estimate.totalHours, closeTo(37.8 * (0.01 + 2 * 0.04), 0.00001));
    settings.preparationRates[PaintPreparation.dusting] = 0.5;
    expect(estimate.settings.preparationRates[PaintPreparation.dusting], 0.01);
  });

  test('clips and unions openings and counts windows on selected walls', () {
    final walls = lines(PreferredUnitSystem.metric);
    final openings = [
      for (final type in PlasterOpeningType.values)
        PlasterRoomOpening.forInsert(
          lineId: 1,
          type: type,
          offsetFromStart: 0,
          width: 10000,
          height: 20000,
          sillHeight: 0,
        ),
    ];
    var estimate = PaintEstimate.fromRoom(
      room(PreferredUnitSystem.metric),
      walls,
      openings,
      PaintSettings(colours: 3),
    );
    expect(estimate.wallArea, closeTo(26.8, 0.00001));
    expect(estimate.windows, 1);
    expect(estimate.colourHours, 0.5);
    estimate = PaintEstimate.fromRoom(
      room(PreferredUnitSystem.metric),
      walls,
      openings,
      PaintSettings(excludedWalls: {1}, ceiling: false),
    );
    expect(estimate.wallArea, closeTo(21.6, 0.00001));
    expect(estimate.windows, 0);
    expect(estimate.ceilingArea, 0);
  });

  test('imperial room dimensions convert to square metres', () {
    final estimate = PaintEstimate.fromRoom(
      room(PreferredUnitSystem.imperial),
      lines(PreferredUnitSystem.imperial),
      [],
      PaintSettings(),
    );
    expect(estimate.ceilingArea, closeTo(100 * 0.09290304, 0.00001));
    expect(estimate.wallArea, closeTo(40 * 8 * 0.09290304, 0.00001));
  });

  test('custom rates roundtrip and invalid counts are rejected', () {
    final settings = PaintSettings(
      preparation: PaintPreparation.mediumRepairs,
      finish: PaintFinish.textured,
      coats: 3,
      colours: 2,
      windowHours: 2,
    );
    settings.preparationRates[PaintPreparation.mediumRepairs] = 0.3;
    final saved = PaintSettings.fromMap(settings.toMap());
    expect(saved.preparationRates[PaintPreparation.mediumRepairs], 0.3);
    expect(saved.finish, PaintFinish.textured);
    expect(saved.coats, 3);
    expect(() => PaintSettings(coats: 0).validate(), throwsFormatException);
    expect(
      () => PaintSettings(windowHours: double.nan).validate(),
      throwsFormatException,
    );
  });
}
