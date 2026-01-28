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

import '../oauth/redirect_handler.dart';

class XeroRedirectHandlerConfig implements RedirectHandlerConfig {
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
