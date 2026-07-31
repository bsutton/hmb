import 'dart:io';

import 'package:hmb/util/flutter/notifications/notif.dart';
import 'package:test/test.dart';

void main() {
  test('todo notification uses a stable id and payload', () {
    final remindAt = DateTime(2026, 7, 14, 9);

    final notification = Notif.forToDo(
      todoId: 42,
      title: 'Order materials',
      remindAt: remindAt,
    );

    expect(notification.id, 20_000_042);
    expect(notification.body, 'Order materials');
    expect(notification.scheduledAtMillis, remindAt.millisecondsSinceEpoch);
    expect(notification.payload, {'type': 'todo', 'id': '42'});
    expect(notification.channel.id, 'HMB_NOTIF_TODO');
  });

  test('job notification is scheduled thirty minutes before its start', () {
    final startsAt = DateTime(2026, 7, 14, 9);

    final notification = Notif.forJobActivity(
      activityId: 7,
      jobId: 12,
      jobSummary: 'Repair leaking tap',
      startsAt: startsAt,
    );

    expect(notification.id, 30_000_007);
    expect(
      DateTime.fromMillisecondsSinceEpoch(notification.scheduledAtMillis),
      DateTime(2026, 7, 14, 8, 30),
    );
    expect(notification.payload?['jobId'], '12');
    expect(notification.channel.id, 'HMB_NOTIF_JOB');
  });

  test('only Todo and job activity ids are managed', () {
    expect(Notif.idForToDo(42), 20_000_042);
    expect(Notif.idForJobActivity(7), 30_000_007);
    expect(Notif.isManagedId(20_000_042), isTrue);
    expect(Notif.isManagedId(30_000_007), isTrue);
    expect(Notif.isManagedId(999001), isFalse);
    expect(Notif.isManagedId(40_000_000), isFalse);
  });

  test('Android declares scheduled notification receivers', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android.permission.RECEIVE_BOOT_COMPLETED'));
    expect(manifest, contains('ScheduledNotificationReceiver'));
    expect(manifest, contains('ScheduledNotificationBootReceiver'));
  });
}
