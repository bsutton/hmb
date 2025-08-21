import 'package:sqflite_common/sqlite_api.dart';

import '../entity/entity.g.dart';
import '../util/exceptions.dart' show TaskMoveException;
import 'dao.g.dart';

extension JobCopyMove on DaoJob {
  /// Copy a [Job] and move selected [Task]s to the new [Job]
  Future<Job> copyJobAndMoveTasks({
    required Job job,
    required List<Task> tasksToMove,
    JobStatus? newJobStatus,
    Transaction? transaction,
  }) async {
    final daoTask = DaoTask();
    final daoTaskItem = DaoTaskItem();
    final daoTimeEntry = DaoTimeEntry();
    final daoWAT = DaoWorkAssignmentTask();
    final daoQuote = DaoQuote();
    final daoQuoteLineGroup = DaoQuoteLineGroup();

    // Validate [Task]s belong to the [Job]
    final tasks = <Task>[];
    for (final task in tasksToMove) {
      if (task.jobId != job.id) {
        throw TaskMoveException(
          'Task ${task.name} does not belong to job ${job.description}.',
        );
      }
    }

    // Preload approved quotes (only if Fixed Price)
    final approvedQuotes = job.billingType == BillingType.fixedPrice
        ? (await daoQuote.getByJobId(
            job.id,
          )).where((q) => q.state == QuoteState.approved).toList()
        : const <Quote>[];

    // Check business rules
    final nonMovableReasons = <Task, String>{};
    for (final t in tasks) {
      final billed = await daoTask.isTaskBilled(
        task: t,
        daoTaskItem: daoTaskItem,
        daoTimeEntry: daoTimeEntry,
      );
      if (billed) {
        nonMovableReasons[t] = 'has billed items or time.';
        continue;
      }
      final hasWA = await daoTask.hasWorkAssignment(task: t, daoWAT: daoWAT);
      if (hasWA) {
        nonMovableReasons[t] = 'is linked to a work assignment.';
        continue;
      }

      if (await daoTask.isTaskLockedByApprovedFixedQuote(
        job: job,
        task: t,
        approvedQuotes: approvedQuotes,
        daoQLG: daoQuoteLineGroup,
      )) {
        nonMovableReasons[t] =
            '''is part of an approved fixed-price quote and the quote line group is not rejected.''';
        continue;
      }
    }

    if (nonMovableReasons.isNotEmpty) {
      final b = StringBuffer('One or more tasks cannot be moved:\n');
      nonMovableReasons.forEach((id, why) {
        b.writeln(' - Task $id: $why');
      });
      throw TaskMoveException(b.toString());
    }

    // Use withinTransaction so everything is atomic
    return withTransaction((transaction) async {
      final now = DateTime.now();

      // 1. Insert new job
      final inserted =
          Job.forInsert(
              customerId: job.customerId,
              summary: job.summary,
              description: job.description,
              assumption: job.assumption,
              siteId: job.siteId,
              contactId: job.contactId,
              status: newJobStatus ?? JobStatus.startingStatus,
              hourlyRate: job.hourlyRate,
              bookingFee: job.bookingFee,
              billingContactId: job.billingContactId,
              billingType: job.billingType,
            )
            ..lastActive = true
            ..createdDate = now
            ..modifiedDate = now;

      final newJobId = await insert(inserted, transaction);
      final newJob = (await getById(newJobId))!;

      // 2. Move tasks by updating jobId
      for (final t in tasks) {
        final moved = Task.forUpdate(
          entity: t,
          jobId: newJobId,
          name: t.name,
          description: t.description,
          assumption: t.assumption,
          status: t.status,
        );
        await daoTask.update(moved, transaction);
      }

      final srcTouched = job
        ..modifiedDate = DateTime.now()
        ..lastActive = false;
      await update(srcTouched, transaction);

      return newJob;
    });
  }
}
