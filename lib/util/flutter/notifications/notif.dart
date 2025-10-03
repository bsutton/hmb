/*
 Copyright © OnePub IP Pty Ltd.
 All Rights Reserved.
*/

import 'package:meta/meta.dart';

class Channel {
  const Channel._({
    required this.id,
    required this.name,
    required this.description,
  });

  factory Channel.todo() => const Channel._(
    id: 'HMB_NOTIF_TODO',
    name: 'TODO_REMINDERS',
    description: 'Todo Reminders',
  );

  factory Channel.test() => const Channel._(
    id: 'HMB_NOTIF_TEST',
    name: 'TEST_REMINDERS',
    description: 'Test Reminders',
  );
  final String id;
  final String name;
  final String description;
}

/// A lightweight description of a local notification.
@immutable
class Notif {
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
}
