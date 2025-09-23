import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../dao/dao.g.dart';
import '../../entity/entity.g.dart';
import '../widgets/widgets.g.dart';
import 'dialog_select_tasks.dart';

Future<void> createInvoiceFor(Job job, BuildContext context) async {
  final options = await selectTasksToInvoice(
    context: context,
    job: job,
    title: 'Tasks to Invoice',
  );
  if (options != null) {
    try {
      if (options.selectedTaskIds.isNotEmpty || options.billBookingFee) {
        await createTimeAndMaterialsInvoice(
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
