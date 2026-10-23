import 'package:material_ui/material_ui.dart';

import '../../dao/dao.g.dart';
import '../../entity/entity.g.dart';
import '../crud/milestone/edit_milestone_payment.dart';
import '../widgets/widgets.g.dart';
import 'edit_invoice_screen.dart';
import 'invoice_details.dart';
import 'prepare_invoice_screen.dart';

Future<Invoice?> createInvoiceFor(
  Job job,
  BuildContext context, {
  int? milestoneId,
  int? taskId,
}) async {
  final invoice = await Navigator.of(context).push<Invoice>(
    MaterialPageRoute(
      builder: (_) => PrepareInvoiceScreen(
        jobId: job.id,
        milestoneId: milestoneId,
        taskId: taskId,
      ),
    ),
  );
  if (invoice != null && context.mounted) {
    await openPreparedInvoice(context, invoice);
  }
  return invoice;
}

Future<void> openPreparedInvoice(BuildContext context, Invoice invoice) async {
  final details = await BlockingUI().runAndWait(
    () => InvoiceDetails.load(invoice.id),
  );
  if (!context.mounted) {
    return;
  }
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => InvoiceEditScreen(invoiceDetails: details),
    ),
  );
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
      'Create a quote to split its agreed price into milestone payments.',
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
      HMBCancelButton(onPressed: () => Navigator.of(dialogContext).pop()),
    ],
  ),
);
