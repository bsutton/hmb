import 'package:flutter/widgets.dart';

/// Stable widget keys used by UI automation.
///
/// These keys are not part of the visual UI. Keep them stable so fdb and
/// widget tests can drive forms without relying on text labels or coordinates.
class TestKeys {
  static const recordPaymentAmountField = ValueKey(
    'record_payment_amount_field',
  );
  static const recordPaymentMethodField = ValueKey(
    'record_payment_method_field',
  );
  static const recordPaymentReferenceField = ValueKey(
    'record_payment_reference_field',
  );
  static const recordPaymentNotesField = ValueKey('record_payment_notes_field');
  static const writeOffReasonField = ValueKey('write_off_reason_field');

  static const receiptDateField = ValueKey('receipt_date_field');
  static const receiptPrimaryJobSelector = ValueKey(
    'receipt_primary_job_selector',
  );
  static const receiptSupplierSelector = ValueKey('receipt_supplier_selector');
  static const receiptTotalIncludingTaxField = ValueKey(
    'receipt_total_including_tax_field',
  );
  static const receiptTaxField = ValueKey('receipt_tax_field');
  static const receiptTotalExcludingTaxField = ValueKey(
    'receipt_total_excluding_tax_field',
  );
  static const receiptAddJobAllocationButton = ValueKey(
    'receipt_add_job_allocation_button',
  );

  static ValueKey<String> receiptTaskItemCheckbox(int taskItemId) =>
      ValueKey('receipt_task_item_${taskItemId}_checkbox');

  static ValueKey<String> receiptJobAllocationSelector(int index) =>
      ValueKey('receipt_job_allocation_${index}_selector');

  static ValueKey<String> receiptJobAllocationRemove(int index) =>
      ValueKey('receipt_job_allocation_${index}_remove');

  static ValueKey<String> receiptJobAllocationAmountField(int index) =>
      ValueKey('receipt_job_allocation_${index}_amount_field');

  static const jobCreatorReferredBySelector = ValueKey(
    'job_creator_referred_by_selector',
  );
  static const jobCreatorPrimaryContactSelector = ValueKey(
    'job_creator_primary_contact_selector',
  );
  static const jobCreatorBillingTypeSelector = ValueKey(
    'job_creator_billing_type_selector',
  );
  static const jobCreatorSummaryField = ValueKey('job_creator_summary_field');
  static const jobCreatorDescriptionField = ValueKey(
    'job_creator_description_field',
  );
}
