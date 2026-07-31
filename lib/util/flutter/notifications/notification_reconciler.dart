import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../dao/dao_base.dart';
import '../../../dao/dao_job.dart';
import '../../../dao/dao_job_activity.dart';
import '../../../dao/dao_todo.dart';
import 'local_notifs.dart';
import 'notif.dart';

/// Keeps native notification state aligned with the database.
class NotificationReconciler {
  static final _instance = NotificationReconciler._();

  Timer? _timer;

  factory NotificationReconciler() => _instance;

  NotificationReconciler._();

  void onDaoChanged(DaoBase<dynamic> dao, [int? entityId]) {
    if (dao.tablename != DaoToDo.tableName &&
        dao.tablename != DaoJob.tableName &&
        dao.tablename != DaoJobActivity.tableName) {
      return;
    }

    // DAO callbacks are synchronous and can run inside a transaction. Waiting
    // briefly also coalesces the related Todo + Job updates when a job closes.
    _timer?.cancel();
    _timer = Timer(
      const Duration(milliseconds: 100),
      () => unawaited(
        reconcile().catchError((Object error, StackTrace stackTrace) {
          debugPrint(
            'Failed to reconcile local notifications: $error\n$stackTrace',
          );
        }),
      ),
    );
  }

  Future<void> reconcile() async {
    final notifications = <Notif>[];
    final validIds = <int>{};

    final todos = await DaoToDo().getOpenWithReminders(includePast: true);
    validIds.addAll(todos.map((todo) => Notif.idForToDo(todo.id)));
    final cutoff = DateTime.now().subtract(const Duration(seconds: 60));
    notifications.addAll(
      todos
          .where((todo) => todo.remindAt!.isAfter(cutoff))
          .map(
            (todo) => Notif.forToDo(
              todoId: todo.id,
              title: todo.title,
              remindAt: todo.remindAt!,
            ),
          ),
    );

    final activities = await DaoJobActivity().getStartingAfter(DateTime.now());
    validIds.addAll(
      activities.map((activity) => Notif.idForJobActivity(activity.id)),
    );
    for (final activity in activities) {
      final job = await DaoJob().getById(activity.jobId);
      if (job != null) {
        notifications.add(
          Notif.forJobActivity(
            activityId: activity.id,
            jobId: activity.jobId,
            jobSummary: job.summary,
            startsAt: activity.start,
          ),
        );
      }
    }

    await LocalNotifs().reconcile(notifications, validIds: validIds);
  }
}
