import 'package:hmb/api/oauth/local_server_redirect_handler.dart';
import 'package:hmb/ui/dialog/gmail_redirect_handler_config.dart';
import 'package:test/test.dart';

void main() {
  test('Gmail desktop OAuth uses the IPv4 loopback listener address', () {
    final handler = LocalServerRedirectHandler(GmailRedirectHandlerConfig());

    expect(handler.redirectUri, Uri.parse('http://127.0.0.1:12336/'));
  });
}
