import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/util/dart/measurement_type.dart';
import 'package:hmb/util/dart/units.dart';

void main() {
  group('area measurement defaults', () {
    test('uses square millimetres for metric dimensions', () {
      expect(MeasurementType.area.defaultMetric, same(Units.mm2));
    });

    test('uses square feet for imperial dimensions', () {
      expect(MeasurementType.area.defaultImperial, same(Units.ft2));
    });
  });
}
