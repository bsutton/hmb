import 'package:material_ui/material_ui.dart';

import '../../database/management/backup_providers/google_drive/google_drive_auth.dart';
import '../../integrations/google_calendar/google_calendar_sync.dart';
import '../widgets/blocking_ui.dart';
import '../widgets/hmb_button.dart';
import '../widgets/hmb_toast.dart';

/// Sync a saved schedule change, offering one interactive sign-in and retry.
Future<void> syncScheduleWithGoogleCalendar(
  BuildContext context,
  Future<ExternalCalendarSyncResult> Function() operation, {
  Future<void> Function()? signIn,
}) async {
  Future<ExternalCalendarSyncResult> sync() =>
      BlockingUI().runAndWait(operation, label: 'Syncing Google Calendar');

  try {
    var result = await sync();
    if (result == ExternalCalendarSyncResult.signInRequired) {
      if (!context.mounted) {
        return;
      }
      final connect = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sign in to Google Calendar?'),
          content: const Text(
            'Your schedule change is saved in HMB. Sign in to Google '
            'to update your Google Calendar too.',
          ),
          actions: [
            HMBButtonSecondary(
              label: 'Not now',
              hint: 'Keep the schedule change in HMB only',
              onPressed: () => Navigator.of(context).pop(false),
            ),
            HMBButtonPrimary(
              label: 'Sign in',
              hint: 'Sign in to Google and sync this schedule change',
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      );
      if (connect != true || !context.mounted) {
        return;
      }
      await BlockingUI().runAndWait(
        signIn ??
            () async {
              final auth = await GoogleDriveAuth.instance();
              await auth.signIn();
            },
        label: 'Signing in to Google',
      );
      result = await sync();
    }
    if (result == ExternalCalendarSyncResult.signInRequired) {
      HMBToast.info(
        'Schedule saved in HMB. Google Calendar was not updated because '
        'sign-in was not completed.',
      );
    } else if (result == ExternalCalendarSyncResult.unavailable) {
      HMBToast.info(
        'Schedule saved in HMB. Google Calendar is unavailable on this device.',
      );
    }
  } catch (error) {
    HMBToast.error('Schedule saved, but Google Calendar sync failed: $error');
  }
}
