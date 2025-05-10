import '../oauth/redirect_handler.dart';

class ChatGptRedirectHandlerConfig implements RedirectHandlerConfig {
  /// Note this port MUST match the port configured via
  /// https://developer.xero.com/ under the list
  /// fo Redirect URIs.
  /// http://localhost:12335/xero/auth_complete
  @override
  int get port => 12335;

  /// On mobile: https://ivanhoehandyman.com.au/xero/auth_complete
  /// On desktop: `http://localhost:<port>/xero/auth_complete`
  @override
  Uri get redirectUri =>
      Uri.parse('https://ivanhoehandyman.com.au/$redirectPath');

  /// The path suffix for finalizing OAuth.
  ///  that Xero should redirect to.
  /// Desktop will use `http://localhost:<port>/xero/auth_complete`
  /// Mobile deep link will use https://ivanhoehandyman.com.au/xero/auth_complete
  @override
  String get redirectPath => 'xero/auth_complete';
}
