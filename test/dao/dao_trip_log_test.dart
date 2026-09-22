import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao_trip_log.dart';
import 'package:hmb/entity/trip_log.dart';

import '../database/management/db_utility_test_helper.dart';

void main() {
  setUp(setupTestDb);
  tearDown(tearDownTestDb);

  test('logging is opt in and ignores movements within 500 metres', () async {
    final dao = DaoTripLog();
    final day = DateTime(2026, 1, 1, 9);
    const start = TripPoint(-37, 145);
    expect(await dao.observe(start, day), isNull);
    await dao.saveSettings(const TripSettings(enabled: true));
    expect(await dao.observe(start, day), isNull);
    expect(
      await dao.observe(
        const TripPoint(-37.002, 145),
        day.add(const Duration(minutes: 10)),
      ),
      isNull,
    );
    final id = await dao.observe(
      const TripPoint(-37.006, 145),
      day.add(const Duration(minutes: 20)),
    );
    expect(id, isNotNull);
    final trip = (await dao.between(
      day,
      day.add(const Duration(days: 1)),
    )).single;
    expect(trip.distanceMetres, isNull);
    expect(trip.business, isFalse);
    expect(trip.departedAt, day.add(const Duration(minutes: 10)));
    expect(trip.from.latitude, start.latitude);
  });

  test(
    'a new day starts from home without fabricating road distance',
    () async {
      final dao = DaoTripLog();
      await dao.saveSettings(
        const TripSettings(enabled: true, home: TripPoint(-37, 145)),
      );
      final at = DateTime(2026, 1, 2, 9);
      await dao.observe(const TripPoint(-37.02, 145), at);
      var trip = (await dao.between(
        at,
        at.add(const Duration(days: 1)),
      )).single;
      expect(trip.fromHome, isTrue);
      expect(trip.departedAt, isNull);
      expect(trip.distanceMetres, isNull);
      await dao.saveRoute(trip, 3000, 600);
      trip = (await dao.between(at, at.add(const Duration(days: 1)))).single;
      expect(trip.departedAt, at.subtract(const Duration(minutes: 10)));
      expect(trip.distanceMetres, 3000);
      expect(await dao.pendingRoutes(), isEmpty);
    },
  );

  test(
    'disabling logging clears the anchor and classification is explicit',
    () async {
      final dao = DaoTripLog();
      final at = DateTime(2026, 1, 1, 9);
      await dao.saveSettings(const TripSettings(enabled: true));
      await dao.observe(const TripPoint(-37, 145), at);
      await dao.saveSettings(const TripSettings());
      await dao.saveSettings(const TripSettings(enabled: true));
      expect(
        await dao.observe(
          const TripPoint(-38, 145),
          at.add(const Duration(hours: 1)),
        ),
        isNull,
      );
      final id = await dao.observe(
        const TripPoint(-38.01, 145),
        at.add(const Duration(hours: 2)),
      );
      await dao.classify(id!, business: true, purpose: 'Purchase supplies');
      final trip = (await dao.between(
        at,
        at.add(const Duration(days: 1)),
      )).single;
      expect(trip.business, isTrue);
      expect(trip.purpose, 'Purchase supplies');
      await expectLater(
        dao.observe(const TripPoint(91, 0), at),
        throwsArgumentError,
      );
    },
  );
}
