/*
 Copyright © OnePub IP Pty Ltd.
 All Rights Reserved.
*/

import 'package:meta/meta.dart';

class Channel {
  final String id;

  final String name;

  final String description;
  factory Channel.test() => const Channel._(
    id: 'HMB_NOTIF_TEST',
    name: 'TEST_REMINDERS',
    description: 'Test Reminders',
  );
  factory Channel.todo() => const Channel._(
    id: 'HMB_NOTIF_TODO',
    name: 'TODO_REMINDERS',
    description: 'Todo Reminders',
  );
  factory Channel.job() => const Channel._(
    id: 'HMB_NOTIF_JOB',
    name: 'JOB_REMINDERS',
    description: 'Schedule Reminders',
  );
  const Channel._({
    required this.id,
    required this.name,
    required this.description,
  });
}

/// A lightweight description of a local notification.
@immutable
class Notif {
  static const todoIdBase = 20_000_000;
  static const jobActivityIdBase = 30_000_000;
  static const _idRangeSize = 10_000_000;

  static const jobActivityReminderLead = Duration(minutes: 30);

  final Channel channel;
  final int id;
  final String title;
  final String body;

  /// Epoch millis in the device's local timezone.
  final int scheduledAtMillis;

  /// Optional small payload (e.g. {"type":"todo","id":"42"}).
  final Map<String, String>? payload;

  const Notif({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledAtMillis,
    required this.channel,
    this.payload,
  });

  factory Notif.forToDo({
    required int todoId,
    required String title,
    required DateTime remindAt,
  }) => Notif(
    id: todoIdBase + todoId,
    title: 'Reminder',
    body: title,
    scheduledAtMillis: remindAt.millisecondsSinceEpoch,
    payload: {'type': 'todo', 'id': '$todoId'},
    channel: Channel.todo(),
  );

  factory Notif.forJobActivity({
    required int activityId,
    required int jobId,
    required String jobSummary,
    required DateTime startsAt,
  }) => Notif(
    id: jobActivityIdBase + activityId,
    title: 'Upcoming job',
    body: '$jobSummary starts soon',
    scheduledAtMillis: startsAt
        .subtract(jobActivityReminderLead)
        .millisecondsSinceEpoch,
    payload: {
      'type': 'job_reminder',
      'activityId': '$activityId',
      'jobId': '$jobId',
    },
    channel: Channel.job(),
  );

  static int idForToDo(int todoId) => todoIdBase + todoId;

  static int idForJobActivity(int activityId) => jobActivityIdBase + activityId;

  static bool isManagedId(int id) =>
      (id >= todoIdBase && id < todoIdBase + _idRangeSize) ||
      (id >= jobActivityIdBase && id < jobActivityIdBase + _idRangeSize);
}
