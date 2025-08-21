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

import 'dart:async';
import 'dart:io';

import 'redirect_handler.dart';
import 'xero_auth.dart';

/// Used to handle the xero auth
/// redirect on completion.
/// Starts a micro http server that handles the xero/auth_complete
/// request.
class LocalServerRedirectHandler extends RedirectHandler {
  /// Note this port MUST match the port configured via
  /// https://developer.xero.com/ under the list
  /// fo Redirect URIs.
  /// http://localhost:12335/xero/auth_complete
  static const portNo = 12335;
  final int port;
  var _running = false;
  HttpServer? server;

  // Singleton instance for the server
  static final _instance = LocalServerRedirectHandler._(portNo);

  // Stream controller for managing subscriptions to auth notifications
  final _authStreamController = StreamController<Uri>.broadcast();

  // Private constructor with port configuration
  LocalServerRedirectHandler._(this.port);

  factory LocalServerRedirectHandler.self() => _instance;

  // Start the server
  @override
  Future<void> start() async {
    if (_running) {
      return;
    }

    _running = true;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _log('listening on http://${server!.address.host}:${server!.port}');

    server!.listen((request) async {
      if (request.uri.path == '/${XeroAuth2.redirectPath}') {
        // Notify all subscribers about the auth completion
        _authStreamController.add(request.requestedUri);

        // Send response to the browser
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.html
          ..write(authCompletePage());
        await request.response.flush();
        await request.response.close();
      } else {
        // Handle other paths or provide a 404
        request.response
          ..statusCode = HttpStatus.notFound
          ..write('404: Not Found');
        await request.response.flush();
        await request.response.close();
      }
    });
  }

  @override
  Uri get redirectUri =>
      Uri.parse('http://localhost:$port/${XeroAuth2.redirectPath}');

  // Close the stream controller when no longer needed
  @override
  Future<void> stop() async {
    _log('Stopping');
    _running = false;

    /// we let the server close gracefully so the
    /// last response is sent before we close down.
    await server?.close();
    server = null;
  }

  @override
  Stream<Uri> get stream => _authStreamController.stream;
}

void _log(String text) {
  print('LocalHostServer: $text');
}

String authCompletePage() => '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Xero Auth Complete</title>
  <style>
    body {
      margin: 0;
      padding: 0;
      font-family: Roboto, Arial, sans-serif;
      background: #f4f4f4;
    }
    .container {
      max-width: 420px;
      margin: 80px auto;
      background: #ffffff;
      border-radius: 8px;
      box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
      text-align: center;
      padding: 32px;
    }
    h2 {
      color: #6200EE; /* Primary Purple */
      margin-bottom: 16px;
      font-size: 1.5rem;
      line-height: 1.2;
    }
    p {
      font-size: 1rem;
      color: #333;
      margin-bottom: 24px;
      line-height: 1.4;
    }
    .button {
      display: inline-block;
      background: #6200EE; /* Primary Purple */
      color: #ffffff;
      text-decoration: none;
      font-weight: 500;
      padding: 12px 24px;
      border-radius: 4px;
      margin-top: 16px;
      transition: background 0.3s ease;
    }
    .button:hover {
      background: #5a00d5; /* Slightly darker purple on hover */
    }
  </style>
</head>
<body>
  <div class="container">
    <h2>Xero Authentication Complete</h2>
    <p>You can return to HMB now.</p>
    <!-- 
      Optional "Go Back" button if you'd like 
      <a href="hmb://deep-link" class="button">Return to App</a> 
    -->
  </div>
</body>
</html>

''';
