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

/// Centralized runtime configuration.
///
/// All secrets and environment-specific values should be read from here,
/// never hardcoded in source files.
///
/// Configuration is resolved in order:
/// 1. Environment variable (highest priority)
/// 2. Compile-time --dart-define value
/// 3. Default fallback (empty string — feature disabled)
class AppConfig {
  AppConfig._();

  /// Sentry DSN for error tracking.
  ///
  /// Set via environment variable `SENTRY_DSN` or
  /// `--dart-define=SENTRY_DSN=...` at build time.
  ///
  /// If not set, Sentry is disabled (empty DSN = no-op).
  static const sentryDsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: '',
  );

  /// Google OAuth Client ID (mobile, signed by Google Play).
  ///
  /// Set via `--dart-define=GOOGLE_CLIENT_ID=...` at build time.
  static const googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: '',
  );

  /// Google OAuth Server Client ID (for backend verification).
  ///
  /// Set via `--dart-define=GOOGLE_SERVER_CLIENT_ID=...` at build time.
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );

  /// Whether Sentry is configured and should be active.
  static bool get isSentryEnabled => sentryDsn.isNotEmpty;
}
