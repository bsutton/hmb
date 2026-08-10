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

import 'package:meta/meta.dart';

@immutable
class XeroCredentials {
  final String? clientSecret;

  const XeroCredentials({required this.clientSecret});
}

@immutable
class ChatGptCredentials {
  final String? accessToken;
  final String? refreshToken;

  const ChatGptCredentials({
    required this.accessToken,
    required this.refreshToken,
  });
}

@immutable
class OpenAiCredentials {
  final String? apiKey;

  const OpenAiCredentials({required this.apiKey});
}

@immutable
class GoogleMapsCredentials {
  final String? apiKey;

  const GoogleMapsCredentials({required this.apiKey});
}

@immutable
class IhserverCredentials {
  final String? token;

  const IhserverCredentials({required this.token});
}

@immutable
class SmtpCredentials {
  final String? password;

  const SmtpCredentials({required this.password});
}
