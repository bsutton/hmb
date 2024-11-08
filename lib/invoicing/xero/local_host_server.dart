import 'dart:async';
import 'dart:io';

import 'redirect_handler.dart';
import 'xero_auth.dart';

/// Used to handle the xero auth
/// redirect on completion.
/// Starts a micro http server that handles the xero/auth_complete
/// request.
class LocalHostServer extends RedirectHandler {
  factory LocalHostServer() => _instance;

  // Private constructor with port configuration
  LocalHostServer._(this.port);

  factory LocalHostServer.self() => _instance;

  /// Note this port MUST match the port configured via
  /// https://developer.xero.com/ under the list
  /// fo Redirect URIs.
  /// http://localhost:12335/xero/auth_complete
  static int portNo = 12335;
  final int port;
  bool running = false;
  HttpServer? server;

  // Singleton instance for the server
  static final LocalHostServer _instance = LocalHostServer._(portNo);

  // Stream controller for managing subscriptions to auth notifications
  final StreamController<Uri> _authStreamController =
      StreamController<Uri>.broadcast();

  // Start the server
  @override
  Future<void> start() async {
    if (running) {
      return;
    }

    running = true;
    server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      port,
    );
    print('Listening on http://${server!.address.host}:${server!.port}');

    await for (final HttpRequest request in server!) {
      if (request.uri.path == '/${XeroAuth2.redirectPath}') {
        // Notify all subscribers about the auth completion
        _authStreamController.add(request.requestedUri);

        // Send response to the browser
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.html
          ..write('''
<html><body><h1>Authentication Complete!</h1>
<p>You can return to HMB.</p></body></html>''');
        await request.response.close();
      } else {
        // Handle other paths or provide a 404
        request.response
          ..statusCode = HttpStatus.notFound
          ..write('404: Not Found');
        await request.response.close();
      }
    }
  }

  // Subscribe to the auth completion stream
  Stream<Uri> get onAuthComplete => _authStreamController.stream;

  @override
  Uri get redirectUri =>
      Uri.parse('http://localhost:$port/${XeroAuth2.redirectPath}');

  // Close the stream controller when no longer needed
  @override
  Future<void> stop() async {
    await _authStreamController.close();
    await server?.close(force: true);
  }

  @override
  Stream<Uri> get stream => onAuthComplete;
}
