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

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_timezone_2025/flutter_native_timezone_2025.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../entity/todo.dart';
import 'desktop_scheduler.dart';
import 'notif.dart';

class LocalNotifs {
  // Small drift guard to avoid "fire on save" when times are near-now.
  static const _grace = Duration(seconds: 60);

  // For test reliability: short schedules can race AlarmManager/Doze.
  static const _minLead = Duration(seconds: 90);

  static final _instance = LocalNotifs._();

  final _fln = FlutterLocalNotificationsPlugin();
  DesktopNotifScheduler? _desktop;
  var _inited = false;
  var _iana = 'UTC';

  factory LocalNotifs() => _instance;

  LocalNotifs._();

  Future<void> init() async {
    if (_inited) {
      return;
    }

    // ---- timezone (for mobile/mac zonedSchedule) ----
    await _initLocalTimeZone();

    // ---- per-platform init ----
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings();
    const linuxInit = LinuxInitializationSettings(
      defaultActionName: 'Open notification',
    );
    const windowsInit = WindowsInitializationSettings(
      guid: '{4F25C8B5-DA21-4C1E-8B31-DC5F5A30E71F}',
      appName: 'HMB',
      appUserModelId: 'dev.onepub.hmb',
    );

    const init = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
      linux: linuxInit,
      windows: windowsInit,
    );

    await _fln.initialize(
      settings: init,
      onDidReceiveNotificationResponse: (resp) {
        // decode payload and route if needed
        _decodePayload(resp.payload);
        // TODO(chat-gpt): route using data['type'], data['id']
      },
    );

    // ---- permissions ----
    if (Platform.isAndroid) {
      final android = _fln
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.requestNotificationsPermission();
      // NOTE: If you later require exact alarms, add the manifest permission
      // and deep-link users to the exact-alarm settings screen.
    } else if (Platform.isIOS) {
      final ios = _fln
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);
    } else if (Platform.isMacOS) {
      final macos = _fln
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      await macos?.requestPermissions(alert: true, badge: true, sound: true);
    }

    // ---- desktop in-app scheduler (Windows/Linux only) ----
    if (Platform.isWindows || Platform.isLinux) {
      _desktop = DesktopNotifScheduler(fln: _fln, buildDetails: _buildDetails)
        ..start();
    }

    _inited = true;
    debugPrint('LocalNotifs init complete. tz=$_iana');
  }

  // Build per-platform details in one place (reused by desktop scheduler).
  NotificationDetails _buildDetails(Notif n) => NotificationDetails(
    android: AndroidNotificationDetails(
      n.channel.id,
      n.channel.name,
      channelDescription: n.channel.description,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
    ),
    iOS: const DarwinNotificationDetails(),
    macOS: const DarwinNotificationDetails(),
    linux: const LinuxNotificationDetails(),
    windows: const WindowsNotificationDetails(
      scenario: WindowsNotificationScenario.reminder,
    ),
  );

  Future<void> schedule(Notif n) async {
    await init();

    // Normalize: treat n.scheduledAtMillis as a local wall-clock instant.
    // We recreate a TZDateTime in tz.local to preserve wall-clock semantics
    // across DST boundaries.
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    final ms = n.scheduledAtMillis;

    // Avoid near-now races; enforce a minimum lead time.
    var target = DateTime.fromMillisecondsSinceEpoch(ms);
    final minAllowed = now.add(_minLead);
    if (target.isBefore(minAllowed)) {
      target = minAllowed;
    }

    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      // Rebuild as TZDateTime in current tz.local (DST-safe).
      final whenTz = tz.TZDateTime(
        tz.local,
        target.year,
        target.month,
        target.day,
        target.hour,
        target.minute,
        target.second,
        target.millisecond,
        target.microsecond,
      );

      // If after the grace and min-lead it's still in the past, skip.
      if (whenTz.isBefore(tz.TZDateTime.now(tz.local).add(_grace))) {
        return;
      }

      await _fln.zonedSchedule(
        id: n.id,
        title: n.title,
        body: n.body,
        scheduledDate: whenTz,
        notificationDetails: _buildDetails(n),
        // Inexact saves battery and avoids exact-alarm permission.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: _encodePayload(n.payload),
      );
    } else if (Platform.isWindows || Platform.isLinux) {
      // Enqueue into in-app scheduler (fires while app is open).
      // If way in the past (beyond grace), skip enqueue.
      if (ms + _grace.inMilliseconds < nowMs) {
        return;
      }
    }

    // Track in desktop queue for visibility/resync.
    _desktop?.upsert(
      Notif(
        id: n.id,
        title: n.title,
        body: n.body,
        scheduledAtMillis: target.millisecondsSinceEpoch,
        payload: n.payload,
        channel: Channel.todo(),
      ),
    );
  }

  Future<void> cancel(int id) async {
    await init();
    _desktop?.cancel(id); // desktop queue too
    await _fln.cancel(id: id);
  }

  Future<void> cancelAll() async {
    await init();
    _desktop?.clear();
    await _fln.cancelAll();
  }

  /// Schedule from ToDo (store LOCAL → schedule in LOCAL tz).
  Future<void> scheduleForToDo(ToDo todo) async {
    final when = todo.remindAt;
    if (when == null) {
      return;
    }

    final n = Notif(
      id: _idForToDo(todo.id),
      title: 'Reminder',
      body: todo.title,
      // `when` is LOCAL; keep it local by passing its epoch straight through.
      scheduledAtMillis: when.millisecondsSinceEpoch,
      payload: {'type': 'todo', 'id': '${todo.id}'},
      channel: Channel.todo(),
    );
    await schedule(n);
  }

  Future<void> cancelForToDo(int todoId) => cancel(_idForToDo(todoId));

  /// Optional: resync desktop scheduler from current open To-Dos.
  /// Call this on app start or after a big data refresh.
  Future<void> resyncFromToDos(Iterable<ToDo> todos) async {
    await init();
    if (!Platform.isWindows && !Platform.isLinux) {
      return;
    }

    final notifs = todos
        .where((t) => t.remindAt != null && t.status == ToDoStatus.open)
        .map(
          (t) => Notif(
            id: _idForToDo(t.id),
            title: 'Reminder',
            body: t.title,
            scheduledAtMillis: t.remindAt!.millisecondsSinceEpoch,
            payload: {'type': 'todo', 'id': '${t.id}'},
            channel: Channel.todo(),
          ),
        );

    _desktop?.resync(notifs);
  }

  // ---- Helpers -------------------------------------------------------------

  int _idForToDo(int todoId) => 20_000_000 + todoId;

  String? _encodePayload(Map<String, String>? p) {
    if (p == null || p.isEmpty) {
      return null;
    }
    final parts = <String>[];
    for (final e in p.entries) {
      parts.add('${e.key}=${e.value}');
    }
    return parts.join(';');
  }

  Map<String, String> _decodePayload(String? s) {
    if (s == null || s.isEmpty) {
      return const {};
    }
    final out = <String, String>{};
    for (final part in s.split(';')) {
      final eq = part.indexOf('=');
      if (eq > 0) {
        out[part.substring(0, eq)] = part.substring(eq + 1);
      }
    }
    return out;
  }

  Future<void> _initLocalTimeZone() async {
    tzdata.initializeTimeZones();

    // Prefer native IANA from plugin. Fall back on platform files/env. Last
    // resort: UTC.
    String name;
    try {
      if (Platform.isAndroid ||
          Platform.isIOS ||
          Platform.isMacOS ||
          Platform.isWindows) {
        name = await FlutterNativeTimezone.getLocalTimezone();
      } else if (Platform.isLinux) {
        name = await _ianaFromLinux();
      } else {
        name = 'UTC';
      }
    } catch (_) {
      name = await _ianaFromLinux();
    }

    // Validate against tz db; fall back to UTC if unknown.
    try {
      tz.setLocalLocation(tz.getLocation(name));
      _iana = name;
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
      _iana = 'UTC';
    }
  }

  Future<String> _ianaFromLinux() async {
    try {
      final etcTimezone = File('/etc/timezone');
      if (etcTimezone.existsSync()) {
        final name = (await etcTimezone.readAsString()).trim();
        if (name.isNotEmpty) {
          return name;
        }
      }
      final localtime = File('/etc/localtime');
      if (localtime.existsSync()) {
        final target = await localtime.resolveSymbolicLinks();
        final m = RegExp(r'zoneinfo/(.+)$').firstMatch(target);
        final name = m?.group(1);
        if (name != null && name.isNotEmpty) {
          return name;
        }
      }
      final envTz = Platform.environment['TZ'];
      if (envTz != null && envTz.isNotEmpty) {
        return envTz;
      }
    } catch (_) {
      /* fall through */
    }
    return 'UTC';
  }

  // Quick end-to-end test. Keeps your original debug helper intact,
  // but with safer timing + interpretation.
  Future<void> debugNotifPipeline(FlutterLocalNotificationsPlugin fln) async {
    final androidImpl = fln
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final granted = await androidImpl?.areNotificationsEnabled() ?? true;
    debugPrint('POST_NOTIFICATIONS granted: $granted');

    final channel = Channel.test();
    await fln.show(
      id: 999001,
      title: 'Test immediate',
      body: 'If you see me, posting works',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
        ),
        iOS: const DarwinNotificationDetails(),
        macOS: const DarwinNotificationDetails(),
      ),
      payload: 'ping=now',
    );

    // Use >= 90s lead to avoid scheduling races.
    final when = tz.TZDateTime.now(tz.local).add(_minLead);
    await fln.zonedSchedule(
      id: 999002,
      title: 'Test scheduled',
      body: 'Should appear ~${_minLead.inSeconds}s from now',
      scheduledDate: when,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'hmb_default',
          'Reminders',
          channelDescription: 'Reminders and alerts',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'ping=scheduled',
    );

    final when2 = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 2));
    await _fln.zonedSchedule(
      id: 990002,
      title: 'Schedule test',
      body: 'Should land in ~2 minutes',
      scheduledDate: when,
      notificationDetails: _buildDetails(
        Notif(
          id: 0,
          title: '',
          body: '',
          scheduledAtMillis: when2.millisecondsSinceEpoch,
          channel: Channel.test(),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'diag=1',
    );

    final pending = await fln.pendingNotificationRequests();
    debugPrint('Pending count: ${pending.length}');
    for (final p in pending) {
      debugPrint('Pending -> id=${p.id}, title=${p.title}');
    }
  }
}
