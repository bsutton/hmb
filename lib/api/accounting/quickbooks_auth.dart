import 'dart:convert';
import 'dart:math';

import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:synchronized/synchronized.dart';

import '../../dao/dao_quickbooks.dart';
import '../../dao/dao_system.dart';
import '../../entity/quickbooks_settings.dart';
import '../../entity/system_credentials.dart';

/// Bring-your-own Intuit app. No client secret is bundled with HMB.
/// Tokens and client secrets live only in the platform credential store.
class QuickBooksAuth {
  static final _lock = Lock();
  oauth2.AuthorizationCodeGrant? _grant;
  QuickBooksSettings? _settings;
  DateTime? _started;

  Future<Uri> begin() async {
    final settings = await DaoQuickBooks().settings();
    settings.validateAuth();
    final secrets = await DaoSystem().getQuickBooksCredentials();
    if (secrets.clientSecret == null || secrets.clientSecret!.isEmpty) {
      throw const FormatException('Enter your Intuit client secret first.');
    }
    cancel();
    _settings = settings;
    _started = DateTime.now();
    _grant = oauth2.AuthorizationCodeGrant(
      settings.clientId,
      Uri.parse('https://appcenter.intuit.com/connect/oauth2'),
      Uri.parse('https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer'),
      secret: secrets.clientSecret,
    );
    final random = Random.secure();
    final state = base64UrlEncode(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    return _grant!.getAuthorizationUrl(
      Uri.parse(settings.redirectUri),
      scopes: ['com.intuit.quickbooks.accounting'],
      state: state,
    );
  }

  Future<void> complete(String callback) async {
    final grant = _grant;
    final settings = _settings;
    if (grant == null ||
        settings == null ||
        _started == null ||
        DateTime.now().difference(_started!) > const Duration(minutes: 10)) {
      throw const FormatException('Start a new QuickBooks connection.');
    }
    final uri = Uri.tryParse(callback.trim());
    final expected = Uri.parse(settings.redirectUri);
    final realm = uri?.queryParameters['realmId'];
    if (uri == null ||
        uri.scheme != expected.scheme ||
        uri.host != expected.host ||
        uri.port != expected.port ||
        uri.path != expected.path ||
        realm == null ||
        !RegExp(r'^\d+$').hasMatch(realm)) {
      throw const FormatException(
        'The callback does not match this connection.',
      );
    }
    try {
      final client = await grant.handleAuthorizationResponse(
        uri.queryParameters,
      );
      try {
        final secrets = await DaoSystem().getQuickBooksCredentials();
        await DaoSystem().updateQuickBooksCredentials(
          QuickBooksCredentials(
            clientSecret: secrets.clientSecret,
            tokenJson: client.credentials.toJson(),
            realmId: realm,
          ),
        );
      } finally {
        client.close();
      }
    } catch (_) {
      throw const FormatException(
        'QuickBooks authorization failed. Start again; '
        'check the app credentials, callback and approval.',
      );
    } finally {
      cancel();
    }
  }

  void cancel() {
    _grant?.close();
    _grant = null;
    _settings = null;
    _started = null;
  }

  Future<T> withClient<T>(
    Future<T> Function(oauth2.Client client, String realmId) action,
  ) => _lock.synchronized(() async {
    final settings = await DaoQuickBooks().settings();
    final secrets = await DaoSystem().getQuickBooksCredentials();
    if (secrets.tokenJson == null || secrets.realmId == null) {
      throw const FormatException(
        'Connect to QuickBooks in integration settings first.',
      );
    }
    var credentials = oauth2.Credentials.fromJson(secrets.tokenJson!);
    if (credentials.expiration == null ||
        credentials.expiration!.isBefore(
          DateTime.now().add(const Duration(minutes: 1)),
        )) {
      credentials = await credentials.refresh(
        identifier: settings.clientId,
        secret: secrets.clientSecret,
      );
      await DaoSystem().updateQuickBooksCredentials(
        QuickBooksCredentials(
          clientSecret: secrets.clientSecret,
          tokenJson: credentials.toJson(),
          realmId: secrets.realmId,
        ),
      );
    }
    final client = oauth2.Client(
      credentials,
      identifier: settings.clientId,
      secret: secrets.clientSecret,
    );
    try {
      return await action(client, secrets.realmId!);
    } finally {
      try {
        await DaoSystem().updateQuickBooksCredentials(
          QuickBooksCredentials(
            clientSecret: secrets.clientSecret,
            tokenJson: client.credentials.toJson(),
            realmId: secrets.realmId,
          ),
        );
      } finally {
        client.close();
      }
    }
  });
}
