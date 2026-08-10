import 'package:hmb/entity/site.dart';
import 'package:test/test.dart';

void main() {
  test('copyWith can invalidate cached geocode data', () {
    final site = Site.forInsert(
      addressLine1: '1 Main St',
      addressLine2: '',
      suburb: 'Ivanhoe',
      state: 'VIC',
      postcode: '3079',
      accessDetails: '',
      latitude: -37.7,
      longitude: 145,
      geocodeStatus: 'ok',
      geocodedAt: DateTime(2026),
    );

    final updated = site.copyWith(
      addressLine1: '2 Main St',
      clearGeocode: true,
      geocodeStatus: 'invalidated',
    );

    expect(updated.addressLine1, '2 Main St');
    expect(updated.latitude, isNull);
    expect(updated.longitude, isNull);
    expect(updated.geocodedAt, isNull);
    expect(updated.geocodeStatus, 'invalidated');
  });

  test('address display cleans comma fragments before joining', () {
    final site = Site.forInsert(
      addressLine1: 'Apt 101,Level 1, 1 Wilfred Road, ',
      addressLine2: '',
      suburb: 'Ivanhoe East',
      state: '',
      postcode: '',
      accessDetails: '',
    );

    expect(site.address, 'Apt 101, Level 1, 1 Wilfred Road, Ivanhoe East');
  });
}
