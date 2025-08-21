/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/


// test/local_date_test.dart

import 'package:hmb/util/local_date.dart';
import 'package:test/test.dart';

void main() {
  group('LocalDate.addMonths', () {
    test('adds months within same year', () {
      final d = LocalDate(2025, 3, 15);
      expect(d.addMonths(2), equals(LocalDate(2025, 5, 15)));
    });

    test('clamps end-of-month for February in a non-leap year', () {
      final jan31 = LocalDate(2021, 1, 31);
      final result = jan31.addMonths(1);
      // 2021 is not a leap year, so Feb has 28 days
      expect(result, equals(LocalDate(2021, 2, 28)));
    });

    test('clamps end-of-month for February in a leap year', () {
      final jan31leap = LocalDate(2024, 1, 31);
      final result = jan31leap.addMonths(1);
      // 2024 is a leap year, so Feb has 29 days
      expect(result, equals(LocalDate(2024, 2, 29)));
    });

    test('crosses year boundary correctly', () {
      final nov30 = LocalDate(2025, 11, 30);
      final result = nov30.addMonths(3);
      // Nov → Dec → Jan → Feb; Feb 30 → clamped to Feb 28 (2026 non-leap)
      expect(result, equals(LocalDate(2026, 2, 28)));
    });

    test('subtracts months with negative input', () {
      final mar31 = LocalDate(2025, 3, 31);
      final result = mar31.addMonths(-1);
      // March 31 → Feb 28 (2025 non-leap)
      expect(result, equals(LocalDate(2025, 2, 28)));
    });

    test('zero months returns same date', () {
      final d = LocalDate(2025, 7, 20);
      expect(d.addMonths(0), equals(d));
    });
  });
}
