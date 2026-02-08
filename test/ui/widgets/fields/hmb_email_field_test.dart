import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/ui/widgets/fields/hmb_email_field.dart';

void main() {
  group('LowerCaseTextFormatter', () {
    test('preserves cursor selection when lower-casing', () {
      final formatter = LowerCaseTextFormatter();
      const oldValue = TextEditingValue(text: 'test@example.com');
      const newValue = TextEditingValue(
        text: 'Test@example.com',
        selection: TextSelection.collapsed(offset: 1),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, equals('test@example.com'));
      expect(result.selection.baseOffset, equals(1));
      expect(result.selection.extentOffset, equals(1));
    });

    test('returns unchanged value when already lowercase', () {
      final formatter = LowerCaseTextFormatter();
      const oldValue = TextEditingValue(text: 'test@example.com');
      const newValue = TextEditingValue(
        text: 'test@example.com',
        selection: TextSelection.collapsed(offset: 2),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, equals('test@example.com'));
      expect(result.selection.baseOffset, equals(2));
      expect(result.selection.extentOffset, equals(2));
    });
  });
}
