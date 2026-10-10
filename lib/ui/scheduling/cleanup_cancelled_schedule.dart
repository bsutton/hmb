import '../../database/management/database_helper.dart';
import '../../integrations/google_calendar/cancelled_schedule_cleanup.dart';
import '../../integrations/google_calendar/google_calendar_sync.dart';
import '../../util/flutter/notifications/local_notifs.dart';
import '../widgets/blocking_ui.dart';
import '../widgets/hmb_toast.dart';

CancelledScheduleCleanup cancelledScheduleCleanup() => CancelledScheduleCleanup(
  db: DatabaseHelper.instance.database,
  deleteCalendar: GoogleCalendarSyncService().deleteActivity,
  cancelReminder: LocalNotifs().cancelForJobActivity,
);

Future<void> cleanupCancelledSchedule({int? jobId}) async {
  try {
    final pending = await BlockingUI().runAndWait(
      () => cancelledScheduleCleanup().retry(jobId: jobId),
      label: 'Removing cancelled bookings',
    );
    if (pending > 0) {
      HMBToast.info(
        'Bookings removed from HMB. $pending booking(s) still need calendar '
        'or reminder cleanup. Retry in Settings > Integrations > '
        'Google Calendar.',
      );
    }
  } catch (_) {
    HMBToast.error(
      'Bookings removed from HMB. Cleanup is pending; retry in '
      'Settings > Integrations > Google Calendar.',
    );
  }
}
