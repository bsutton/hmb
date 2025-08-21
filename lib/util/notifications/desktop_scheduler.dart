/*
 Copyright © OnePub IP Pty Ltd.
 All Rights Reserved.
*/

import 'dart:async';
import 'dart:collection';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notif.dart';

/// Very small in-app scheduler for desktop (Windows/Linux).
/// Only fires while the app is running.
///
/// Uses wall-clock UTC millis to avoid TZ drift.
class DesktopNotifScheduler {
  final FlutterLocalNotificationsPlugin _fln;
  final NotificationDetails Function(Notif) _buildDetails;
  final Duration _tick;
  final Duration _fireGrace;

  Timer? _timer;

  /// Keyed by UTC millis → list of notifs at that instant.
  final SplayTreeMap<int, List<Notif>> _queue = SplayTreeMap();

  DesktopNotifScheduler({
    required FlutterLocalNotificationsPlugin fln,
    required NotificationDetails Function(Notif) buildDetails,
    Duration tick = const Duration(seconds: 15),
    Duration fireGrace = const Duration(seconds: 60),
  }) : _fln = fln,
       _buildDetails = buildDetails,
       _tick = tick,
       _fireGrace = fireGrace;

  bool get isRunning => _timer?.isActive ?? false;

  void start() {
    _timer ??= Timer.periodic(_tick, (_) => _tickCheck());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void clear() => _queue.clear();

  /// Insert or replace by id.
  void upsert(Notif n) {
    // Remove any existing entry with same id
    _removeById(n.id);

    final t = n.scheduledAtMillis;
    _queue.putIfAbsent(t, () => <Notif>[]).add(n);
  }

  void cancel(int id) => _removeById(id);

  /// Resync the queue from a list of notifs (or from To-Dos mapped to notifs).
  void resync(Iterable<Notif> items) {
    _queue.clear();
    for (final n in items) {
      upsert(n);
    }
  }

  // ---- internals -----------------------------------------------------------

  Future<void> _tickCheck() async {
    final nowUtcMs = DateTime.now().toUtc().millisecondsSinceEpoch;

    // Collect all keys <= now+grace
    final cutoff = nowUtcMs + _fireGrace.inMilliseconds;
    final dueKeys = <int>[];
    for (final key in _queue.keys) {
      if (key <= cutoff) {
        dueKeys.add(key);
      } else {
        break; // map is ordered
      }
    }
    if (dueKeys.isEmpty) {
      return;
    }

    for (final key in dueKeys) {
      final items = _queue.remove(key) ?? const <Notif>[];
      for (final n in items) {
        // If still clearly in the past beyond grace, skip firing.
        if (n.scheduledAtMillis + _fireGrace.inMilliseconds < nowUtcMs) {
          continue;
        }
        await _fln.show(
          n.id,
          n.title,
          n.body,
          _buildDetails(n),
          payload: _encodePayload(n.payload),
        );
      }
    }
  }

  void _removeById(int id) {
    final toDelete = <int, int>{}; // key -> index within list
    _queue.forEach((k, list) {
      final idx = list.indexWhere((e) => e.id == id);
      if (idx != -1) {
        toDelete[k] = idx;
      }
    });
    toDelete.forEach((k, idx) {
      final list = _queue[k];
      if (list == null) {
        return;
      }
      list.removeAt(idx);
      if (list.isEmpty) {
        _queue.remove(k);
      }
    });
  }

  String? _encodePayload(Map<String, String>? p) {
    if (p == null || p.isEmpty) {
      return null;
    }
    // keep same format you already used
    return p.entries.map((e) => '${e.key}=${e.value}').join(';');
  }
}
