import 'package:flutter/widgets.dart';

/// Stable widget keys used by UI automation.
///
/// These keys are not part of the visual UI. Keep them stable so fdb and
/// widget tests can drive forms without relying on text labels or coordinates.
class TestKeys {
  static const ValueKey<String> recordPaymentAmountField = ValueKey(
    'record_payment_amount_field',
  );
  static const ValueKey<String> recordPaymentMethodField = ValueKey(
    'record_payment_method_field',
  );
  static const ValueKey<String> recordPaymentReferenceField = ValueKey(
    'record_payment_reference_field',
  );
  static const ValueKey<String> recordPaymentNotesField = ValueKey(
    'record_payment_notes_field',
  );
  static const ValueKey<String> writeOffReasonField = ValueKey(
    'write_off_reason_field',
  );

  static const ValueKey<String> receiptDateField = ValueKey(
    'receipt_date_field',
  );
  static const ValueKey<String> receiptPrimaryJobSelector = ValueKey(
    'receipt_primary_job_selector',
  );
  static const ValueKey<String> receiptSupplierSelector = ValueKey(
    'receipt_supplier_selector',
  );
  static const ValueKey<String> receiptTotalIncludingTaxField = ValueKey(
    'receipt_total_including_tax_field',
  );
  static const ValueKey<String> receiptTaxField = ValueKey('receipt_tax_field');
  static const ValueKey<String> receiptTotalExcludingTaxField = ValueKey(
    'receipt_total_excluding_tax_field',
  );
  static const ValueKey<String> receiptAddJobAllocationButton = ValueKey(
    'receipt_add_job_allocation_button',
  );

  static ValueKey<String> receiptEditButton(int receiptId) =>
      ValueKey('receipt_${receiptId}_edit_button');

  static ValueKey<String> receiptTaskItemCheckbox(int taskItemId) =>
      ValueKey('receipt_task_item_${taskItemId}_checkbox');

  static ValueKey<String> receiptJobAllocationSelector(int index) =>
      ValueKey('receipt_job_allocation_${index}_selector');

  static ValueKey<String> receiptJobAllocationRemove(int index) =>
      ValueKey('receipt_job_allocation_${index}_remove');

  static ValueKey<String> receiptJobAllocationAmountField(int index) =>
      ValueKey('receipt_job_allocation_${index}_amount_field');

  static ValueKey<String> receiptLineMoveUp(int index) =>
      ValueKey('receipt_line_${index}_move_up');

  static ValueKey<String> receiptLineMoveDown(int index) =>
      ValueKey('receipt_line_${index}_move_down');

  static ValueKey<String> receiptLineRemove(int index) =>
      ValueKey('receipt_line_${index}_remove');

  static const ValueKey<String> jobCreatorReferredBySelector = ValueKey(
    'job_creator_referred_by_selector',
  );
  static const ValueKey<String> jobCreatorPrimaryContactSelector = ValueKey(
    'job_creator_primary_contact_selector',
  );
  static const ValueKey<String> jobCreatorBillingTypeSelector = ValueKey(
    'job_creator_billing_type_selector',
  );
  static const ValueKey<String> jobCreatorSummaryField = ValueKey(
    'job_creator_summary_field',
  );
  static const ValueKey<String> jobCreatorDescriptionField = ValueKey(
    'job_creator_description_field',
  );

  static const ValueKey<String> fixedPriceInvoiceMilestonesButton = ValueKey(
    'fixed_price_invoice_milestones_button',
  );
  static const ValueKey<String> fixedPriceInvoiceTimeAndMaterialsButton =
      ValueKey('fixed_price_invoice_time_and_materials_button');

  static ValueKey<String> plasterboardProjectEditButton(int projectId) =>
      ValueKey('plasterboard_project_${projectId}_edit_button');
}
