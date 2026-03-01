# Invoicing Implementation Plan

This plan implements the rules in `invoicing.md` for the new invoicing
behavior. It focuses on task-level billing overrides, quote-as-source-of-truth,
post-quote task handling, per-line rejection, milestone rules, and the related
UI flows.

## Scope Summary
- Enforce quote rules and task-level billing overrides across quote and invoice
  generation.
- Separate quoted vs unquoted work so new tasks after acceptance can be billed
  directly.
- Enforce milestone rules: milestones only from accepted quotes; void if quote
  later rejected.
- Add UI warnings and prompts for post-quote edits and quote rejection.
- Update "To be Invoiced" view to surface unquoted tasks.
- Add tests for the new rules and workflows.

## Data Model and Migration
- Add or confirm `task.billing_type` nullable with inheritance.
- Ensure `quote_line_group` supports per-line rejection status and task linkage.
- Ensure milestones link to quotes and are voidable when quote rejected.
- Confirm `task_item.total_line_charge` and `margin` migration rules.

Files likely involved:
- `assets/sql/upgrade/scripts/*`
- `assets/sql/upgrade_list.json`
- `lib/entity/task.dart`
- `lib/entity/quote_line_group.dart`
- `lib/entity/milestone.dart`

## Domain Logic Changes
### Billing Type Resolution
- Implement a single `effectiveBillingType` resolver for task/job.
- Update invoice/quote calculators to use task-level overrides consistently.

Files likely involved:
- `lib/dao/dao_task.dart`
- `lib/dao/dao_invoice_create_by_task.dart`
- `lib/dao/dao_invoice_create_by_date.dart`
- `lib/dao/dao_invoice_time_and_materials.dart`
- `lib/dao/dao_invoice_fixed_price.dart`
- `lib/dao/dao_quote.dart`

### Quote Rules and States
- Allow per-line rejection and ensure it rejects the linked task.
- Allow quote acceptance with rejected tasks.
- Enforce single open and single accepted quote per job.
- On quote rejection, prompt to reject job and handle job rejection behavior.

Files likely involved:
- `lib/dao/dao_quote.dart`
- `lib/dao/dao_quote_line_group.dart`
- `lib/dao/dao_job.dart`
- `lib/dao/dao_task.dart`

### Milestone Enforcement
- Only allow milestone creation for accepted quotes.
- If accepted quote is later rejected, void milestones and disallow new ones.
- Define "void milestone" as non-invoiceable and flagged as voided for history
  and filtering. If `invoice_id` is set, the milestone cannot be voided until
  the invoice is deleted or voided first.

Files likely involved:
- `lib/dao/dao_milestone.dart`
- `lib/dao/dao_quote.dart`
- `lib/ui/crud/milestone/edit_milestone_payment.dart`

### Quoted vs Unquoted Task Handling
- Track which tasks are part of an accepted quote.
- Allow direct invoicing for unquoted tasks added after acceptance.
- Ensure quoted tasks are blocked from direct invoicing without milestones.

Files likely involved:
- `lib/dao/dao_task.dart`
- `lib/dao/dao_job.dart`
- `lib/dao/dao_invoice_create_by_task.dart`
- `lib/ui/invoicing/dialog_select_tasks.dart`
- `lib/ui/invoicing/yet_to_be_invoice.dart`

## UI Changes
### Quote List and Details
- Add per-line reject controls and show task rejection state.
- Allow acceptance with rejected lines.
- On reject, prompt to optionally reject job.

Files likely involved:
- `lib/ui/quoting/quote_card.dart`
- `lib/ui/quoting/quote_details.dart`
- `lib/ui/quoting/quote_details_screen.dart`
- `lib/ui/quoting/edit_quote_line_dialog.dart`

### Task Editing Warnings
- When editing tasks/items on accepted quotes, show warning that quote is the
  source of truth and billing will not change.
- Allow edits but show warnings for scope-impacting changes.

Files likely involved:
- `lib/ui/task_items/*`
- `lib/ui/crud/*` (task and task item editors)

### Invoicing Flows
- Task selection dialog should separate quoted vs unquoted tasks.
- "To be Invoiced" list should include unquoted tasks even after acceptance.
- Direct invoice creation should be blocked for quoted tasks when a quote is
  accepted unless invoicing via milestones.

Files likely involved:
- `lib/ui/invoicing/dialog_select_tasks.dart`
- `lib/ui/invoicing/yet_to_be_invoice.dart`
- `lib/ui/invoicing/list_invoice_screen.dart`

### Milestones UI
- Disallow milestone creation when quote not accepted.
- If quote later rejected, show status and disable milestone edits.

Files likely involved:
- `lib/ui/crud/milestone/edit_milestone_payment.dart`
- `lib/ui/crud/milestone/milestone_tile.dart`

## Tests
- Quote lifecycle: single open/accepted, accept with rejected tasks, reject
  accepted quote with manual cleanup.
- Per-line rejection rejects task and excludes from billing.
- Task-level billing override affects quote and invoice calculations.
- Post-quote added tasks appear in "To be Invoiced" and can be billed directly.
- Milestone restrictions and voiding on quote rejection.

Likely test locations:
- `test/dao/*`
- `test/feature/*`
- `test/sql/*` (migration fixtures)

## Phased Implementation
1. Data model and migrations
2. Billing calculators and DAO rules
3. Quote workflow and milestone enforcement
4. UI flows and warnings
5. Tests and validation
