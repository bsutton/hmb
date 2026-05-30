@Tags(['flutter'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/ui/dialog/email_self_warning.dart';

void main() {
  group('includesOwnEmail', () {
    test('detects own email case-insensitively', () {
      expect(
        includesOwnEmail(
          ownEmail: 'Me@Example.com',
          recipients: ['customer@example.com', ' me@example.com '],
        ),
        isTrue,
      );
    });

    test('ignores blank own email', () {
      expect(
        includesOwnEmail(ownEmail: '', recipients: ['me@example.com']),
        isFalse,
      );
    });

    test('returns false when own email is not selected', () {
      expect(
        includesOwnEmail(
          ownEmail: 'me@example.com',
          recipients: ['customer@example.com'],
        ),
        isFalse,
      );
    });
  });
}
