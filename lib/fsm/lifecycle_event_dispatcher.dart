import 'package:sqflite_common/sqlite_api.dart';

import '../dao/dao.g.dart';
import '../entity/entity.g.dart';
import 'job_events.dart';
import 'lifecycle_models.dart';
import 'lifecycle_rules.dart';
import 'quote_events.dart';

/// The only application boundary allowed to persist lifecycle state.
///
/// Each command reloads its aggregate inside the transaction so a stale UI
/// model can never overwrite a newer transition.
class LifecycleEventDispatcher {
  Database get _db => DatabaseHelper.instance.database;

  Future<int> scheduleActivity(
    JobActivity activity, {
    required LifecycleContext context,
  }) async {
    final activityId = await _db.transaction((transaction) async {
      final id = await DaoJobActivity().insert(activity, transaction);
      final job = await DaoJob().getById(activity.jobId, transaction);
      if (job == null) {
        throw LifecycleException('Job ${activity.jobId} no longer exists.');
      }
      await _advanceJobForSchedule(job, context, transaction);
      return id;
    });
    _notifyJobCommand(activity.jobId);
    Dao.notifier(DaoJobActivity(), activityId);
    return activityId;
  }

  Future<void> updateScheduledActivity(
    JobActivity activity, {
    required LifecycleContext context,
  }) async {
    final originalJobId = await _db.transaction((transaction) async {
      final original = await DaoJobActivity().getById(activity.id, transaction);
      if (original == null) {
        throw LifecycleException(
          'Schedule activity ${activity.id} no longer exists.',
        );
      }
      await DaoJobActivity().update(activity, transaction);
      final job = await DaoJob().getById(activity.jobId, transaction);
      if (job == null) {
        throw LifecycleException('Job ${activity.jobId} no longer exists.');
      }
      if (original.jobId != activity.jobId ||
          job.status != JobStatus.completed) {
        await _advanceJobForSchedule(job, context, transaction);
      }
      if (original.jobId != activity.jobId) {
        await _returnUnscheduledJobIfEmpty(
          original.jobId,
          context,
          transaction,
        );
      }
      return original.jobId;
    });
    _notifyJobCommand(activity.jobId);
    if (originalJobId != activity.jobId) {
      _notifyJobCommand(originalJobId);
    }
    Dao.notifier(DaoJobActivity(), activity.id);
  }

  Future<void> deleteScheduledActivity(
    int activityId, {
    required LifecycleContext context,
  }) async {
    final jobId = await _db.transaction((transaction) async {
      final activity = await DaoJobActivity().getById(activityId, transaction);
      if (activity == null) {
        return null;
      }
      await DaoJobActivity().delete(activityId, transaction);
      await _returnUnscheduledJobIfEmpty(activity.jobId, context, transaction);
      return activity.jobId;
    });
    if (jobId != null) {
      _notifyJobCommand(jobId);
    }
    Dao.notifier(DaoJobActivity(), activityId);
  }

  Future<void> _advanceJobForSchedule(
    Job job,
    LifecycleContext context,
    Transaction transaction,
  ) async {
    var current = job;
    if (current.status == JobStatus.rejected) {
      throw const LifecycleException('A rejected job cannot be scheduled.');
    }
    if (current.status == JobStatus.completed) {
      final event = ReopenForScheduling(current);
      final target = targetForJobEvent(current.status, event)!;
      current = (await _applyJobTransition(
        job: current,
        event: event,
        target: target,
        context: context,
        transaction: transaction,
      )).entity;
    } else {
      final event = ProceedToScheduling(current);
      final target = targetForJobEvent(current.status, event);
      if (target != null) {
        current = (await _applyJobTransition(
          job: current,
          event: event,
          target: target,
          context: context,
          transaction: transaction,
        )).entity;
      }
    }
    if (current.status == JobStatus.toBeScheduled) {
      final event = ScheduleJob(current);
      final target = targetForJobEvent(current.status, event)!;
      await _applyJobTransition(
        job: current,
        event: event,
        target: target,
        context: context,
        transaction: transaction,
      );
    }
  }

  Future<void> _returnUnscheduledJobIfEmpty(
    int jobId,
    LifecycleContext context,
    Transaction transaction,
  ) async {
    final remaining = await transaction.query(
      DaoJobActivity.tableName,
      columns: ['id'],
      where: 'job_id = ?',
      whereArgs: [jobId],
      limit: 1,
    );
    if (remaining.isNotEmpty) {
      return;
    }
    final job = await DaoJob().getById(jobId, transaction);
    if (job == null || job.status != JobStatus.scheduled) {
      return;
    }
    final event = ScheduleRemoved(job);
    final target = targetForJobEvent(job.status, event)!;
    await _applyJobTransition(
      job: job,
      event: event,
      target: target,
      context: context,
      transaction: transaction,
    );
  }

  Future<void> validateQuote(
    int quoteId,
    QuoteEvent Function(Quote) buildEvent,
  ) => _db.transaction((transaction) async {
    final quote = await DaoQuote().getById(quoteId, transaction);
    if (quote == null) {
      throw LifecycleException('Quote $quoteId no longer exists.');
    }
    final event = buildEvent(quote);
    if (targetForQuoteEvent(quote.state, event) == null) {
      throw LifecycleException(
        '${event.name} is not valid while the quote is ${quote.state.name}.',
      );
    }
    await _validateQuoteTransition(quote, event, transaction);
    if (event is RejectQuoteAndJob) {
      final job = await DaoJob().getById(quote.jobId, transaction);
      if (job != null &&
          job.status != JobStatus.rejected &&
          targetForJobEvent(job.status, RejectJob(job)) == null) {
        throw LifecycleException(
          'The ${job.status.displayName} job cannot be rejected.',
        );
      }
    }
  });

  Future<LifecycleResult<Job>> dispatchJob(
    int jobId,
    JobEvent Function(Job) buildEvent, {
    required LifecycleContext context,
  }) async {
    final result = await _db.transaction((transaction) async {
      final job = await DaoJob().getById(jobId, transaction);
      if (job == null) {
        throw LifecycleException('Job $jobId no longer exists.');
      }
      final event = buildEvent(job);
      final target = targetForJobEvent(job.status, event);
      if (target == null) {
        throw LifecycleException(
          '${event.name} is not valid while the job is '
          '${job.status.displayName}.',
        );
      }

      return await _applyJobTransition(
        job: job,
        event: event,
        target: target,
        context: context,
        transaction: transaction,
      );
    });
    _notifyJobCommand(jobId);
    return result;
  }

  Future<LifecycleResult<Job>> _applyJobTransition({
    required Job job,
    required JobEvent event,
    required JobStatus target,
    required LifecycleContext context,
    required Transaction transaction,
  }) async {
    final from = job.status;
    final changed = from != target;
    final now = context.requestedAt.toIso8601String();
    final resumeStatus = switch (event) {
      PauseJob() => job.resumeStatus ?? from,
      WaitForMaterials() => job.resumeStatus ?? from,
      _ => null,
    };
    final resumeChanged = resumeStatus != job.resumeStatus;

    if (changed || resumeChanged) {
      await transaction
          .update(
            DaoJob.tableName,
            {
              'status_id': target.id,
              'resume_status_id': resumeStatus?.id,
              'modified_date': now,
            },
            where: 'id = ? AND status_id = ?',
            whereArgs: [job.id, from.id],
          )
          .then((count) {
            if (count != 1) {
              throw const LifecycleException(
                'The job changed while the action was being applied.',
              );
            }
          });
    }

    await _runJobEntryActions(job.id, target, event, transaction, now);

    if (target == JobStatus.rejected) {
      await _rejectQuotesForJob(job.id, context, transaction);
    }

    await DaoLifecycleTransition().insert(
      aggregateType: 'job',
      aggregateId: job.id,
      jobId: job.id,
      event: event.name,
      fromState: from.id,
      toState: target.id,
      context: context,
      transaction: transaction,
    );

    final updated = await DaoJob().getById(job.id, transaction);
    return LifecycleResult(
      entity: updated!,
      event: event.name,
      from: from.id,
      to: target.id,
      changed: changed,
    );
  }

  Future<LifecycleResult<Quote>> dispatchQuote(
    int quoteId,
    QuoteEvent Function(Quote) buildEvent, {
    required LifecycleContext context,
  }) async {
    final result = await _db.transaction((transaction) async {
      final quote = await DaoQuote().getById(quoteId, transaction);
      if (quote == null) {
        throw LifecycleException('Quote $quoteId no longer exists.');
      }
      final event = buildEvent(quote);
      final target = targetForQuoteEvent(quote.state, event);
      if (target == null) {
        throw LifecycleException(
          '${event.name} is not valid while the quote is ${quote.state.name}.',
        );
      }
      await _validateQuoteTransition(quote, event, transaction);
      if (event is RejectQuoteAndJob) {
        final job = await DaoJob().getById(quote.jobId, transaction);
        if (job != null &&
            job.status != JobStatus.rejected &&
            targetForJobEvent(job.status, RejectJob(job)) == null) {
          throw LifecycleException(
            'The ${job.status.displayName} job cannot be rejected.',
          );
        }
      }

      final from = quote.state;
      final now = context.requestedAt.toIso8601String();
      final values = <String, Object?>{
        'state': target.name,
        'modified_date': now,
      };
      if (event is SendQuote) {
        values['date_sent'] = now;
      }
      if (event is ApproveQuoteEvent) {
        values['date_approved'] = now;
      }

      final count = await transaction.update(
        DaoQuote.tableName,
        values,
        where: 'id = ? AND state = ?',
        whereArgs: [quote.id, from.name],
      );
      if (count != 1) {
        throw const LifecycleException(
          'The quote changed while the action was being applied.',
        );
      }

      if (event is RejectQuoteEvent ||
          event is RejectQuoteAndJob ||
          event is WithdrawQuote ||
          event is AmendQuote) {
        await DaoMilestone().voidByQuoteId(quote.id, transaction: transaction);
      }

      await DaoLifecycleTransition().insert(
        aggregateType: 'quote',
        aggregateId: quote.id,
        jobId: quote.jobId,
        event: event.name,
        fromState: from.name,
        toState: target.name,
        context: context,
        transaction: transaction,
      );

      await _coupleQuoteToJob(quote, event, context, transaction);
      final updated = await DaoQuote().getById(quote.id, transaction);
      return LifecycleResult(
        entity: updated!,
        event: event.name,
        from: from.name,
        to: target.name,
        changed: from != target,
      );
    });
    _notifyQuoteCommand(result.entity);
    return result;
  }

  void _notifyJobCommand(int jobId) {
    Dao.notifier(DaoJob(), jobId);
    Dao.notifier(DaoQuote());
    Dao.notifier(DaoMilestone());
    Dao.notifier(DaoToDo());
  }

  void _notifyQuoteCommand(Quote quote) {
    Dao.notifier(DaoQuote(), quote.id);
    Dao.notifier(DaoJob(), quote.jobId);
    Dao.notifier(DaoMilestone());
    Dao.notifier(DaoToDo());
  }

  Future<void> _validateQuoteTransition(
    Quote quote,
    QuoteEvent event,
    Transaction transaction,
  ) async {
    if (quote.state != QuoteState.approved ||
        (event is! UnapproveQuote &&
            event is! RejectQuoteEvent &&
            event is! RejectQuoteAndJob &&
            event is! AmendQuote)) {
      return;
    }
    final invoiced = await transaction.rawQuery(
      'SELECT 1 FROM milestone '
      'WHERE quote_id = ? AND voided = 0 AND invoice_id IS NOT NULL LIMIT 1',
      [quote.id],
    );
    if (invoiced.isNotEmpty) {
      throw const LifecycleException(
        'An approved quote with an invoiced milestone cannot be changed.',
      );
    }
  }

  Future<void> _coupleQuoteToJob(
    Quote quote,
    QuoteEvent event,
    LifecycleContext context,
    Transaction transaction,
  ) async {
    final job = await DaoJob().getById(quote.jobId, transaction);
    if (job == null) {
      throw LifecycleException('Job ${quote.jobId} no longer exists.');
    }

    JobEvent? jobEvent;
    if (event is SendQuote &&
        (job.status == JobStatus.prospecting ||
            job.status == JobStatus.quoting)) {
      jobEvent = SubmitQuote(job);
    } else if (event is ApproveQuoteEvent &&
        job.status == JobStatus.awaitingApproval) {
      jobEvent = ApproveQuote(job);
    } else if (event is UnapproveQuote &&
        job.status == JobStatus.awaitingPayment) {
      final otherApproved = await transaction.rawQuery(
        'SELECT 1 FROM quote WHERE job_id = ? AND id != ? '
        'AND state IN (?, ?) LIMIT 1',
        [job.id, quote.id, QuoteState.approved.name, QuoteState.invoiced.name],
      );
      if (otherApproved.isEmpty) {
        jobEvent = QuoteUnapproved(job);
      }
    } else if (event is RejectQuoteAndJob) {
      jobEvent = RejectJob(job);
    } else if (event is RejectQuoteEvent ||
        event is WithdrawQuote ||
        event is AmendQuote) {
      jobEvent = await _jobEventAfterQuoteRemoval(job, quote.id, transaction);
    }

    if (jobEvent == null) {
      return;
    }
    final target = targetForJobEvent(job.status, jobEvent);
    if (target == null) {
      // Quote actions must never regress an already-active job.
      return;
    }
    await _applyJobTransition(
      job: job,
      event: jobEvent,
      target: target,
      context: context,
      transaction: transaction,
    );
  }

  Future<JobEvent?> _jobEventAfterQuoteRemoval(
    Job job,
    int changedQuoteId,
    Transaction transaction,
  ) async {
    if (job.status != JobStatus.awaitingApproval &&
        job.status != JobStatus.awaitingPayment) {
      return null;
    }

    final remaining = await transaction.query(
      DaoQuote.tableName,
      columns: ['state'],
      where: 'job_id = ? AND id != ?',
      whereArgs: [job.id, changedQuoteId],
    );
    final states = remaining
        .map((row) => QuoteState.values.byName(row['state']! as String))
        .toSet();
    final hasApproved =
        states.contains(QuoteState.approved) ||
        states.contains(QuoteState.invoiced);
    if (hasApproved) {
      return job.status == JobStatus.awaitingApproval
          ? ApproveQuote(job)
          : null;
    }
    final hasSent = states.contains(QuoteState.sent);
    if (hasSent) {
      return job.status == JobStatus.awaitingPayment
          ? QuoteUnapproved(job)
          : null;
    }
    return QuoteNeedsRevision(job);
  }

  Future<void> _runJobEntryActions(
    int jobId,
    JobStatus target,
    JobEvent event,
    Transaction transaction,
    String now,
  ) async {
    if (target == JobStatus.toBeScheduled) {
      final existing = await transaction.rawQuery(
        'SELECT 1 FROM to_do WHERE parent_type = ? AND parent_id = ? '
        'AND status = ? AND lower(trim(title)) = ? LIMIT 1',
        ['job', jobId, 'open', 'schedule job'],
      );
      if (existing.isEmpty) {
        await transaction.insert('to_do', {
          'title': 'Schedule job',
          'priority': 'high',
          'status': 'open',
          'parent_type': 'job',
          'parent_id': jobId,
          'created_date': now,
          'modified_date': now,
        });
      }
    }

    if (target == JobStatus.toBeScheduled ||
        target == JobStatus.scheduled ||
        target == JobStatus.inProgress) {
      final tasks = await DaoTask().getTasksByJob(
        jobId,
        transaction: transaction,
      );
      for (final task in tasks) {
        await DaoTask().jobHasBeenApproved(task, transaction: transaction);
      }
    }

    if (event case StartWork(task: final task?, timeEntry: final timeEntry?)) {
      await DaoTimeEntry().insert(timeEntry, transaction);
      await DaoTask().update(
        task.copyWith(status: TaskStatus.inProgress),
        transaction,
      );
    }

    if (target == JobStatus.completed) {
      await DaoToDo().markDoneByJob(jobId, transaction: transaction);
    }
  }

  Future<void> _rejectQuotesForJob(
    int jobId,
    LifecycleContext context,
    Transaction transaction,
  ) async {
    final quotes = await DaoQuote().getByJobId(jobId, transaction: transaction);
    for (final quote in quotes) {
      if (quote.state == QuoteState.rejected ||
          quote.state == QuoteState.withdrawn) {
        continue;
      }
      if (targetForQuoteEvent(quote.state, RejectQuoteEvent(quote)) == null) {
        throw LifecycleException(
          'Quote ${quote.id} cannot be rejected from ${quote.state.name}.',
        );
      }
      await _validateQuoteTransition(
        quote,
        RejectQuoteEvent(quote),
        transaction,
      );
      await DaoMilestone().voidByQuoteId(quote.id, transaction: transaction);
      await transaction.update(
        DaoQuote.tableName,
        {
          'state': QuoteState.rejected.name,
          'modified_date': context.requestedAt.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [quote.id],
      );
      await DaoLifecycleTransition().insert(
        aggregateType: 'quote',
        aggregateId: quote.id,
        jobId: jobId,
        event: 'RejectQuote',
        fromState: quote.state.name,
        toState: QuoteState.rejected.name,
        context: context,
        transaction: transaction,
      );
    }
  }
}
