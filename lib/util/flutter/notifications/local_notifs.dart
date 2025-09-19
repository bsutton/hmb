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

  static final _instance = LocalNotifs._();

  final _fln = FlutterLocalNotificationsPlugin();
  DesktopNotifScheduler? _desktop;
  var _inited = false;

  factory LocalNotifs() => _instance;

  LocalNotifs._();
  Future<void> init() async {
    if (_inited) {
      return;
    }

    // ---- timezone (for mobile/mac zonedSchedule) ----
    tzdata.initializeTimeZones();
    try {
      final tzName = await _resolveLocalTimeZoneName();
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

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
      init,
      onDidReceiveNotificationResponse: (resp) {
        // decode payload and route if needed
        final data = _decodePayload(resp.payload);
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
  }

  // Build per-platform details in one place (reused by desktop scheduler).
  NotificationDetails _buildDetails(Notif n) => NotificationDetails(
    android: AndroidNotificationDetails(
      n.channelId,
      n.channelName,
      channelDescription: 'Reminders and alerts',
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
    await debugNotifPipeline(_fln);

    // Normalize: treat n.scheduledAtMillis as UTC for cross-platform sanity.
    final ms = n.scheduledAtMillis;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // If slightly in the past (<= grace), nudge forward 1 minute.
    final isSlightlyPast = ms < nowMs && (nowMs - ms) <= _grace.inMilliseconds;
    final targetMs = isSlightlyPast
        ? (nowMs + const Duration(minutes: 1).inMilliseconds)
        : ms;

    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      // Build a local wall-clock time in the current device timezone.
      // This avoids UTC round-trips and preserves 9:00am as 9:00am across DST.
      final local = DateTime.fromMillisecondsSinceEpoch(targetMs);
      final whenTz = tz.TZDateTime(
        tz.local,
        local.year,
        local.month,
        local.day,
        local.hour,
        local.minute,
        local.second,
        local.millisecond,
        local.microsecond,
      );

      // If after grace it's still in the past, skip scheduling.
      if (whenTz.isBefore(tz.TZDateTime.now(tz.local))) {
        return;
      }

      await _fln.zonedSchedule(
        n.id,
        n.title,
        n.body,
        whenTz,
        _buildDetails(n),
        // Inexact saves battery and avoids exact-alarm permission.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: _encodePayload(n.payload),
      );
    } else if (Platform.isWindows || Platform.isLinux) {
      // Enqueue into in-app scheduler (fires while app is open).
      // If way in the past (beyond grace), skip enqueue.
      if (targetMs + _grace.inMilliseconds < nowMs) {
        return;
      }
    }

    _desktop?.upsert(
      Notif(
        id: n.id,
        title: n.title,
        body: n.body,
        scheduledAtMillis: targetMs,
        payload: n.payload,
        channelId: n.channelId,
        channelName: n.channelName,
      ),
    );
  }

  Future<void> cancel(int id) async {
    await init();
    _desktop?.cancel(id); // desktop queue too
    await _fln.cancel(id);
  }

  Future<void> cancelAll() async {
    await init();
    _desktop?.clear();
    await _fln.cancelAll();
  }

  /// Schedule from ToDo (store UTC → schedule UTC).
  Future<void> scheduleForToDo(ToDo todo) async {
    final when = todo.remindAt;
    if (when == null) {
      return;
    }

    final n = Notif(
      id: _idForToDo(todo.id),
      title: 'Reminder',
      body: todo.title,
      // `when` is LOCAL; keep it local by passing its epoch
      //ms straight through.
      scheduledAtMillis: when.millisecondsSinceEpoch,
      payload: {'type': 'todo', 'id': '${todo.id}'},
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
          ),
        );

    _desktop?.resync(notifs);
  }

  int _idForToDo(int todoId) => 20_000_000 + todoId;

  String? _encodePayload(Map<String, String>? p) => (p == null || p.isEmpty)
      ? null
      : p.entries.map((e) => '${e.key}=${e.value}').join(';');

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

  // Resolve IANA timezone name with Linux fallbacks
  Future<String> _resolveLocalTimeZoneName() async {
    try {
      if (Platform.isAndroid ||
          Platform.isIOS ||
          Platform.isMacOS ||
          Platform.isWindows) {
        return await FlutterNativeTimezone.getLocalTimezone();
      } else if (Platform.isLinux) {
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
      }
    } catch (_) {
      /* fall through */
    }
    return 'UTC';
  }

  Future<void> debugNotifPipeline(FlutterLocalNotificationsPlugin fln) async {
    // 1) Permissions
    final androidImpl = fln
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final granted = await androidImpl?.areNotificationsEnabled() ?? true;
    debugPrint('POST_NOTIFICATIONS granted: $granted');

    // 2) Show immediately (channel creation + visuals)
    await fln.show(
      999001,
      'Test immediate',
      'If you see me, posting works',
      const NotificationDetails(
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
      payload: 'ping=now',
    );

    // 3) Schedule +10s (proves scheduling path)
    final when = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10));
    await fln.zonedSchedule(
      999002,
      'Test scheduled',
      'Should appear ~10s from now',
      when,
      const NotificationDetails(
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

    // 4) Inspect pending queue
    final pending = await fln.pendingNotificationRequests();
    debugPrint('Pending count: ${pending.length}');
    for (final p in pending) {
      debugPrint('Pending -> id=${p.id}, title=${p.title}');
    }
  }
}
