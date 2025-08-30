/*
 Copyright © OnePub IP Pty Ltd.
 All Rights Reserved.
*/

import 'package:meta/meta.dart';

/// A lightweight description of a local notification.
@immutable
class Notif {
  final int id;
  final String title;
  final String body;

  /// Epoch millis in the device's local timezone.
  final int scheduledAtMillis;

  /// Optional small payload (e.g. {"type":"todo","id":"42"}).
  final Map<String, String>? payload;

  /// Android channel info.
  final String channelId;
  final String channelName;

  const Notif({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledAtMillis,
    this.payload,
    this.channelId = 'hmb_default',
    this.channelName = 'Reminders',
  });
}
