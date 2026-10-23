import '../entity/entity.g.dart';
import '../util/dart/exceptions.dart';
import 'billing_service.dart';

/// Compatibility entry point. All pricing and writes belong to BillingService.
Future<Invoice> createInvoiceForSelectedTasks(
  Job job,
  Contact billingContact,
  List<int> selectedTaskIds, {
  required bool groupByTask,
  required bool billBookingFee,
}) async {
  if (selectedTaskIds.toSet().length != selectedTaskIds.length) {
    throw InvoiceException('Select each task only once.');
  }
  final service = BillingService();
  final preview = await service.preview(job.id);
  final charges = preview.candidates
      .where(
        (c) =>
            selectedTaskIds.contains(c.taskId) ||
            (billBookingFee && c.kind == 'booking_fee'),
      )
      .toList();
  if (selectedTaskIds.any((id) => !charges.any((c) => c.taskId == id))) {
    throw InvoiceException(
      'A selected task has no available charges. '
      'Record an agreed fixed price or approve a quote for fixed work.',
    );
  }
  return await service.commit(
    preview.select(
      keys: charges.map((c) => c.key),
      contactId: billingContact.id,
      groupByTask: groupByTask,
    ),
  );
}
