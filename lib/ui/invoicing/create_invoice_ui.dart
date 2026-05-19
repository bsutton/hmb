import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../dao/dao.g.dart';
import '../../entity/entity.g.dart';
import '../crud/milestone/edit_milestone_payment.dart';
import '../widgets/widgets.g.dart';
import 'dialog_select_tasks.dart';

enum _FixedPriceInvoicePath { milestones, timeAndMaterials }

Future<void> createInvoiceFor(Job job, BuildContext context) async {
  if (job.billingType == BillingType.fixedPrice) {
    final path = await _selectFixedPriceInvoicePath(job, context);
    if (!context.mounted || path == null) {
      return;
    }
    if (path == _FixedPriceInvoicePath.milestones) {
      await openMilestonesForFixedPriceJob(job: job, context: context);
      return;
    }
  }

  final options = await selectTasksToInvoice(
    context: context,
    job: job,
    title: 'Tasks to Invoice',
    billingTypeFilter: job.billingType == BillingType.fixedPrice
        ? BillingType.timeAndMaterial
        : null,
  );
  if (options != null) {
    try {
      if (options.selectedTaskIds.isNotEmpty || options.billBookingFee) {
        await createInvoiceForSelectedTasks(
          job,
          options.contact,
          options.selectedTaskIds,
          groupByTask: options.groupByTask,
          billBookingFee: options.billBookingFee,
        );
        HMBToast.info('Invoice created for "${job.summary}".');
        if (context.mounted) {
          context.go('/home/accounting/invoices');
          return;
        }
      } else {
        HMBToast.info('Select at least one Task or the Booking Fee.');
      }
    } catch (e) {
      HMBToast.error(
        'Failed to create invoice: $e',
        acknowledgmentRequired: true,
      );
    }
  }
}

Future<_FixedPriceInvoicePath?> _selectFixedPriceInvoicePath(
  Job job,
  BuildContext context,
) async {
  if (!await _hasAccruedTimeAndMaterialsTasks(job)) {
    return _FixedPriceInvoicePath.milestones;
  }

  if (!context.mounted) {
    return null;
  }

  return showDialog<_FixedPriceInvoicePath>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Invoice "${job.summary}"'),
      content: const Text(
        'This fixed price job also has time and materials work ready to '
        'invoice.',
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(dialogContext, _FixedPriceInvoicePath.milestones),
          child: const Text('Milestones'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(
            dialogContext,
            _FixedPriceInvoicePath.timeAndMaterials,
          ),
          child: const Text('Time & Materials'),
        ),
      ],
    ),
  );
}

Future<bool> _hasAccruedTimeAndMaterialsTasks(Job job) async {
  final values = await DaoTask().getAccruedValueForJob(
    job: job,
    includedBilled: false,
  );
  for (final value in values) {
    if (value.task.effectiveBillingType(job.billingType) ==
        BillingType.timeAndMaterial) {
      final earned = await value.earned;
      if (!earned.isZero) {
        return true;
      }
    }
  }
  return false;
}

Future<bool> openMilestonesForFixedPriceJob({
  required Job job,
  required BuildContext context,
}) async {
  final quotes = await DaoQuote().getByJobId(job.id);
  if (!context.mounted) {
    return false;
  }
  if (quotes.isEmpty) {
    HMBToast.error(
      'This fixed price job has no quote. Create a quote before invoicing.',
      acknowledgmentRequired: true,
    );
    return false;
  }

  final quote = quotes.length == 1
      ? quotes.first
      : await _selectQuoteForJob(context: context, quotes: quotes, job: job);

  if (quote == null || !context.mounted) {
    return false;
  }

  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => EditMilestonesScreen(quoteId: quote.id),
    ),
  );
  return true;
}

Future<Quote?> _selectQuoteForJob({
  required BuildContext context,
  required List<Quote> quotes,
  required Job job,
}) => showDialog<Quote>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    title: Text('Select Quote for "${job.summary}"'),
    content: SizedBox(
      width: 420,
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: quotes.length,
        itemBuilder: (_, index) {
          final quote = quotes[index];
          return ListTile(
            title: Text('Quote #${quote.bestNumber}'),
            subtitle: Text(quote.summary),
            onTap: () => Navigator.of(dialogContext).pop(quote),
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(dialogContext).pop(),
        child: const Text('Cancel'),
      ),
    ],
  ),
);
