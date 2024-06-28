// ignore_for_file: lines_longer_than_80_chars

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:oidc/oidc.dart';
import 'package:oidc_default_store/oidc_default_store.dart';
import 'package:strings/strings.dart';

import '../dao/dao_system.dart';
import '../util/exceptions.dart';
import '../widgets/hmb_toast.dart';
import 'models/models.dart';

class XeroAuthScreen extends StatefulWidget {
  const XeroAuthScreen({super.key});

  static const routeName = '/xero-auth';

  @override
  // ignore: library_private_types_in_public_api
  _XeroAuthScreenState createState() => _XeroAuthScreenState();
}

class Credentials {}

class XeroCredentials implements Credentials {
  XeroCredentials({
    required this.clientId,
    required this.clientSecret,
    // required this.redirectUrl
  });
  String clientId;
  String clientSecret;
  // String redirectUrl;
}

class _XeroAuthScreenState extends State<XeroAuthScreen> {
  String? _accessToken;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _authenticate() async {
    final _scopes = <String>[
      'openid',
      'profile',
      'email',
      'offline_access',
      'accounting.transactions'
    ];

    try {
      final credentials = await _fetchCredentials();
      final manager = OidcUserManager.lazy(
          discoveryDocumentUri: OidcUtils.getOpenIdConfigWellKnownUri(
            Uri.parse('https://identity.xero.com'),
          ),
          clientCredentials: OidcClientAuthentication.clientSecretBasic(
              clientId: credentials.clientId,
              clientSecret: credentials.clientSecret),
          store: OidcDefaultStore(),
          settings: OidcUserManagerSettings(
            scope: _scopes,

            redirectUri: kIsWeb
                // this url must be an actual html page.
                // see the file in /web/redirect.html for an example.
                //
                // for debugging in flutter, you must run this app with --web-port 22433
                // TODO(bsutton): copy a redirect.html from the oidc project
                // somewhere and use that path here.
                ? Uri.parse('http://localhost:22433/redirect.html')
                : Platform.isIOS || Platform.isMacOS || Platform.isAndroid
                    // scheme: reverse domain name notation of your package name.
                    // path: anything.
                    ? Uri.parse('dev.onepub.handyman://app_auth_redirect')
                    : Platform.isWindows || Platform.isLinux
                        // using port 0 means that we don't care which port is used,
                        // and a random unused port will be assigned.
                        //
                        // this is safer than passing a port yourself.
                        //
                        // note that you can also pass a path like /redirect,
                        // but it's completely optional.
                        ? Uri.parse('http://localhost:12335')
                        // ? Uri.parse(
                        //     'https://au.com.ivanhoehandyman/app_auth_redirect')
                        : Uri(),
            // Uri.parse(
            //     'http://ivanhoehandyman.com.au/app_auth_redirect.html')),
          ));

//2. init()
      await manager.init();

//3. listen to user changes
      manager.userChanges().listen((user) {
        print('currentUser changed to $user');
      });

//4. login
      // final newUser = await manager.loginAuthorizationCodeFlow();

//5. logout
      await manager.logout();
    } on InvoiceException catch (e) {
      if (mounted) {
        HMBToast.error(context, e.message);
      }
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      if (mounted) {
        HMBToast.error(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Xero Auth & Invoice'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _authenticate,
                child: const Text('Authenticate with Xero'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async => Invoice.create(_accessToken),
                child: const Text('Create Invoice'),
              ),
            ],
          ),
        ),
      );

  Future<XeroCredentials> _fetchCredentials() async {
    final system = await DaoSystem().get();

    if (system == null ||
        Strings.isBlank(system.xeroClientId) ||
        Strings.isBlank(system.xeroClientSecret)) {
      throw InvoiceException(
          '''The Xero credentials not set. Go to the System screen and set them.''');
    }
    return XeroCredentials(
        clientId: system.xeroClientId!, clientSecret: system.xeroClientSecret!);
  }
}
