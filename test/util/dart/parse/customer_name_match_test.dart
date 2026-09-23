import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/util/dart/parse/customer_name_match.dart';

void main() {
  test('ranks spelling variants above unrelated customers', () {
    final close = customerNameSimilarity(
      'Miles Real Estate',
      'Myles Realestate',
    );
    expect(close, greaterThanOrEqualTo(0.7));
    expect(
      close,
      greaterThan(customerNameSimilarity('Miles Real Estate', 'Jill Doe')),
    );
    expect(
      customerNameSimilarity('Miles Real Estate', 'Miles Real Estate'),
      greaterThan(close),
    );
  });

  test('ignores case, punctuation and repeated whitespace', () {
    expect(
      customerNameSimilarity(' MILES  Real Estate. ', 'Miles Real Estate'),
      1,
    );
  });

  test('empty names do not match', () {
    expect(customerNameSimilarity('', ''), 0);
    expect(customerNameSimilarity('Miles', ''), 0);
  });
}
