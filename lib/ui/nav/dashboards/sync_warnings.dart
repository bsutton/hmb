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

import 'package:june/june.dart';

import '../../../api/external_accounting.dart';

class SyncWarning {
  final String summary;
  final String details;

  const SyncWarning({required this.summary, required this.details});
}

abstract class SyncWarningState extends JuneState {
  SyncWarning? warning;

  void showWarning(String summary, String details) {
    warning = SyncWarning(summary: summary, details: details);
    setState();
  }

  void clearWarning() {
    if (warning == null) {
      return;
    }
    warning = null;
    setState();
  }
}

class AccountingSyncWarningState extends SyncWarningState {
  Future<void> clearIfIntegrationDisabled() async {
    if (warning == null || await ExternalAccounting().isEnabled()) {
      return;
    }
    clearWarning();
  }
}

class BookingRequestsSyncWarningState extends SyncWarningState {}

String formatAccountingSyncWarning(Object error) =>
    'Xero sync needs attention. $error';

String formatBookingSyncWarning(Object error) {
  final message = error.toString().toLowerCase();
  if (message.contains('connection refused') ||
      message.contains('failed host lookup') ||
      message.contains('clientexception') ||
      message.contains('socketexception')) {
    return 'Cannot reach the booking server. Check that ihserver is running '
        'and the URL is correct.';
  }
  if (message.contains('timed out') || message.contains('timeout')) {
    return 'Booking server is taking too long to respond. Please try again.';
  }
  if (message.contains('401') ||
      message.contains('403') ||
      message.contains('unauthorized') ||
      message.contains('forbidden')) {
    return 'Booking sync is not authorized. Check the ihserver token.';
  }
  if (message.contains('500') ||
      message.contains('502') ||
      message.contains('503') ||
      message.contains('504')) {
    return 'Booking server error. Please try again later.';
  }
  return 'Unable to sync booking requests right now. Please try again.';
}
