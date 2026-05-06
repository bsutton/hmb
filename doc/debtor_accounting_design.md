# Debtor Accounting and Reporting Design

This document describes the intended design for debtor-side accounting and
basic financial reporting in HMB.

It is a forward-looking design and does not describe current behavior.

The goal is to extend existing invoicing into a lightweight accounts receivable
and reporting layer that works as a standalone system and can also sync to and
from external accounting systems such as Xero.

HMB should remain a handyman/sole-tradie application. It should help the user
act on jobs, invoices, payments, supplier receipts, and profit. It should not
try to become a full accounting package.

## Scope

- Existing customer invoices.
- Credit notes.
- Partial payments.
- Split payments across multiple invoices.
- Payment and credit allocations.
- Adjustments and write-offs.
- Standalone debtor tracking without external accounting.
- External accounting sync, initially Xero.
- Purchase/supplier receipts as cost inputs.
- Basic financial reports:
  - profit and loss for a month, quarter, financial year, calendar year, and
    custom date range
  - job profit
  - aged receivables
  - debtor/customer statements
  - cash received
  - supplier spend
  - GST summary
  - unreceipted and unlinked costs

## Design Principles

- Treat debtor accounting as a ledger, not as flags on invoices.
- Keep historical debtor events immutable where practical.
- Use explicit reversal entries instead of silently editing financial history.
- Derive invoice status from allocations and balances.
- Keep external accounting links generic so Xero is one provider, not the
  accounting model.
- Keep reports behind reporting services rather than building calculations
  directly in UI widgets.
- Keep HMB job-first. HMB should help a sole tradie act on jobs, billing,
  payments, receipts, and follow-up.
- Use plain language in user-facing screens and reserve accounting terms for
  settings, reports, and sync internals.
- When external accounting is enabled, HMB remains the operational source of
  truth for jobs and job workflow. The external accounting system is the formal
  accounting system of record.

## User Experience Language

Use language that matches a handyman/sole-tradie workflow.

Preferred user-facing terms:

- `Money owed` instead of `debtors`.
- `Payments received` instead of `receipts` for customer payments.
- `Supplier receipts` or `Purchase receipts` for expense receipts.
- `Credits` instead of `credit allocations`.
- `Write off` instead of `bad debt journal`.
- `Money Today` or `Today` for daily action queues.

Internal code and reports may still use precise accounting names where that
keeps the model clear.

## Existing System Fit

HMB already has:

- `invoice` and `invoice_line`.
- `receipt` with supplier, job, tax, and total fields.
- `receipt_task_item` links from receipts to purchased task items.
- receipt photos and tool receipt links.
- invoice totals and due dates.
- `paid` and `paid_date` fields.
- manual vs Xero payment source tracking.
- external invoice IDs and sync status.
- Xero invoice upload and basic paid-state sync.
- invoice voiding behavior.

These should be treated as the starting point. The new ledger should not replace
invoice generation; it should record what happens financially after invoices are
created, sent, credited, paid, adjusted, or voided.

Receipts are purchase-side evidence and cost inputs. They should not be modelled
as debtor transactions, because they do not affect what customers owe. They do,
however, feed P&L, job profit, GST summaries, supplier spend, and unbilled cost
reports.

The existing `invoice.paid` and `invoice.paid_date` fields may remain initially
as compatibility/cache fields, but the target behavior is to derive payment
state from ledger allocations.

## Core Concepts

### Debtor

A debtor is the party that owes money. In HMB this will usually map to the
customer and billing contact for a job.

Reports should support grouping by:

- customer
- contact
- job
- invoice

### Source Document

A source document is a business document that changes the debtor balance.

Initial source document types:

- invoice
- credit note
- adjustment
- write-off
- opening balance
- void/reversal

### Payment

A payment records money received from a customer. A single payment can be:

- allocated to one invoice
- split across multiple invoices
- partly allocated, leaving an unapplied balance
- imported from Xero
- entered manually in standalone mode

### Receipt

A receipt records money spent with a supplier. It belongs to the purchase side
of accounting, not the debtor side.

Current receipt behavior:

- receipt date
- job link
- supplier link
- total excluding tax
- tax
- total including tax
- receipt photos
- optional links to completed buy-type task items
- optional tool receipt link through `tool.receiptId`

Receipts should become the primary source for actual out-of-pocket costs where
they exist.

### Allocation

An allocation applies a payment or credit to one or more invoices. Allocations
are separate records so HMB can represent:

- partial payment of an invoice
- one payment covering multiple invoices
- multiple payments against one invoice
- one credit note applied to multiple invoices
- an unapplied payment or credit

## Proposed Data Model

Table and field names are indicative. Final names should follow repository DAO
and entity conventions.

### `debtor_transaction`

Records the ledger event for a debtor.

Fields:

- `id`
- `debtor_customer_id`
- `debtor_contact_id`
- `job_id`
- `transaction_type`
- `source_table`
- `source_id`
- `transaction_date`
- `amount`
- `tax_amount`
- `description`
- `created_date`
- `modified_date`

`amount` is signed:

- invoices increase debtor balance
- credit notes reduce debtor balance
- payments reduce debtor balance once allocated
- write-offs reduce debtor balance
- reversals negate the original transaction

Receipts are deliberately excluded from `debtor_transaction`. They belong in the
expense/purchase reporting model.

### `payment`

Records money received.

Fields:

- `id`
- `customer_id`
- `contact_id`
- `payment_date`
- `amount`
- `payment_method`
- `reference`
- `notes`
- `external_payment_id`
- `external_provider`
- `created_date`
- `modified_date`

### `payment_allocation`

Allocates payments to invoices.

Fields:

- `id`
- `payment_id`
- `invoice_id`
- `amount`
- `allocated_date`
- `external_allocation_id`
- `created_date`
- `modified_date`

The sum of allocations for a payment must not exceed the payment amount unless
the system explicitly supports correcting entries.

### `credit_note`

Records a customer credit.

Fields:

- `id`
- `customer_id`
- `contact_id`
- `job_id`
- `related_invoice_id`
- `credit_note_num`
- `external_credit_note_id`
- `credit_date`
- `total_amount`
- `status`
- `reason`
- `created_date`
- `modified_date`

Credit note status should include:

- draft
- approved
- allocated
- partially_allocated
- voided

### `credit_note_line`

Mirrors invoice line concepts where practical.

Fields:

- `id`
- `credit_note_id`
- `description`
- `quantity`
- `unit_price`
- `line_total`
- `income_account_code`
- `tax_type`
- `created_date`
- `modified_date`

### `credit_allocation`

Allocates credit notes to invoices.

Fields:

- `id`
- `credit_note_id`
- `invoice_id`
- `amount`
- `allocated_date`
- `external_allocation_id`
- `created_date`
- `modified_date`

### `debtor_adjustment`

Records manual debtor balance changes.

Fields:

- `id`
- `customer_id`
- `contact_id`
- `job_id`
- `invoice_id`
- `adjustment_type`
- `adjustment_date`
- `amount`
- `reason`
- `notes`
- `created_date`
- `modified_date`

Adjustment types:

- rounding
- write_off
- bad_debt
- correction
- opening_balance
- other

Adjustments must require a reason and should be visible in reports and debtor
history.

### `external_accounting_link`

Generic external sync mapping.

Fields:

- `id`
- `provider`
- `entity_type`
- `local_id`
- `external_id`
- `external_number`
- `sync_status`
- `last_synced_at`
- `remote_updated_at`
- `last_error`
- `content_hash`
- `created_date`
- `modified_date`

This table should eventually replace provider-specific sync fields spread across
business entities, but the first implementation can bridge from existing invoice
fields.

### Purchase Reporting Tables

The existing `receipt` table can support basic reporting, but stronger P&L and
job profit reporting needs more detail than a header total.

Recommended future table:

#### `receipt_line`

Fields:

- `id`
- `receipt_id`
- `description`
- `quantity`
- `unit_cost_excluding_tax`
- `tax`
- `total_excluding_tax`
- `total_including_tax`
- `expense_account_code`
- `tax_type`
- `job_id`
- `task_id`
- `task_item_id`
- `tool_id`
- `created_date`
- `modified_date`

This allows a single supplier receipt to cover multiple jobs, tasks, task items,
or tools.

If receipt lines are deferred, add a `receipt_allocation` table so a receipt
header can be split across cost targets. This avoids treating the full receipt
total as the cost of every linked task item.

## Invoice Status

Invoice status should be derived from ledger state.

Statuses:

- `draft`: invoice exists but has not been sent or approved.
- `sent`: invoice has been sent and has an outstanding balance.
- `part_paid`: allocations are greater than zero but less than invoice total.
- `paid`: allocations equal invoice total.
- `overpaid`: allocations exceed invoice total and require correction or
  unapplied credit handling.
- `voided`: invoice has been cancelled.
- `written_off`: balance has been cleared by write-off.

The UI should show these as clear badges:

- Draft
- Sent
- Part paid
- Paid
- Overdue
- Credited
- Written off
- Voided
- Sync issue

Balance formula:

```text
invoice balance =
  invoice total
  - payment allocations
  - credit allocations
  - adjustment allocations
```

The UI may show a cached status for performance, but the canonical value should
come from the ledger service.

## Domain Services

### `DebtorLedgerService`

Owns debtor balance and allocation behavior.

Responsibilities:

- create debtor transaction rows for invoices, credits, payments, and
  adjustments
- calculate invoice balance
- calculate customer balance
- derive invoice status
- apply payments to invoices
- apply credits to invoices
- validate over-allocation
- reverse or void ledger entries
- backfill ledger entries for existing invoices

### `PaymentService`

Responsibilities:

- record manual payment
- split payment across invoices
- hold unapplied payment balances
- import payment from external accounting
- expose payment history for invoice and debtor screens

### `CreditNoteService`

Responsibilities:

- create credit note from an invoice
- create standalone credit note
- allocate credit to invoices
- void or reverse credit notes
- sync credit notes to external accounting

### `PurchaseCostService`

Turns receipts, linked task items, tools, and supplier purchases into reportable
costs.

Responsibilities:

- calculate actual job costs from receipts
- allocate receipt totals to linked task items
- detect possible double-counting between task item costs and receipt costs
- separate capital/tool purchases from job expenses
- expose supplier spend by period
- expose GST paid on purchases
- flag unlinked receipts and unreceipted completed buy items

### `AccountingSyncService`

Coordinates provider sync without embedding provider rules in UI or DAOs.

Responsibilities:

- push local invoices, credit notes, payments, and allocations
- pull remote invoice, credit note, payment, and allocation changes
- resolve external IDs through `external_accounting_link`
- record sync errors
- use idempotency keys where provider APIs support them
- surface conflicts that need user choice

## External Accounting

The accounting adaptor should grow beyond invoices.

Suggested contract:

```text
login()
uploadInvoice(invoice)
voidInvoice(invoice)
uploadCreditNote(creditNote)
voidCreditNote(creditNote)
uploadPayment(payment)
uploadPaymentAllocation(allocation)
uploadCreditAllocation(allocation)
pullInvoiceState(...)
pullCreditNotes(...)
pullPayments(...)
pullAllocations(...)
```

Purchase-side sync should be added under the same provider abstraction when HMB
starts syncing receipts or supplier spend.

Suggested future methods:

```text
uploadReceipt(receipt)
uploadSupplierBill(receipt)
pullSupplierBills(...)
pullSpendMoney(...)
```

### Xero Mapping

Xero concepts map naturally to the proposed model:

- HMB invoice -> Xero invoice.
- HMB credit note -> Xero credit note.
- HMB payment -> Xero payment.
- HMB credit allocation -> Xero credit note allocation.
- HMB receipt -> Xero bill, spend money transaction, or expense claim,
  depending on workflow.
- HMB external link -> Xero IDs and numbers.

Sync should treat payments and allocations as first-class records. It should not
only sync whether an invoice is fully paid.

Receipt sync should be deliberately scoped. A receipt is proof of purchase, but
the equivalent Xero object depends on how the business records expenses:

- supplier invoice/bill if it is unpaid or entered as accounts payable
- spend money if it has already been paid
- expense claim if the owner personally paid and needs reimbursement

The first release can keep receipts local and use them for reporting only.

### Sync Ownership Modes

HMB should support three practical modes:

- standalone: HMB is the source of truth and no external sync is required
- HMB-managed sync: HMB creates documents and pushes them to Xero
- externally-managed sync: Xero can update payment, credit, and allocation state

For mixed cases, conflicts should be explicit. Examples:

- invoice amount changed locally after upload
- payment entered in both HMB and Xero
- credit allocated differently in Xero
- invoice voided in one system but not the other

## Reporting

Reports should be implemented behind a reporting query/service layer so the same
logic can be reused by UI screens, dashboard widgets, PDF export, CSV export,
and tests.

### Report Periods

Supported periods:

- month
- quarter
- financial year
- calendar year
- custom date range

System settings should include the financial year start month. For Australian
businesses this will usually be July.

### Profit and Loss

The initial P&L should default to accrual basis.

Revenue should come from:

- approved or sent invoices
- credit notes as negative revenue
- revenue adjustments

Expenses should come from:

- material costs
- consumables costs
- tool costs where charged or consumed
- supplier receipts
- labour costs where HMB has enough cost data
- expense adjustments

Use receipt totals excluding GST for normal expense reporting. Use the receipt
tax field for GST reporting. GST-inclusive totals are useful for cash and
supplier-spend views, but should not be treated as expense when preparing a
standard P&L.

Receipt cost source priority:

1. receipt lines or receipt allocations, when available
2. linked receipt task items, using allocated receipt amounts if available
3. receipt header total as a job-level cost when no line/allocation detail
   exists
4. task item actual cost only when no receipt-backed cost exists

This priority is required to avoid double-counting the same materials as both a
task item actual cost and a receipt cost.

P&L output:

- income by account/category
- expenses by account/category
- gross profit
- adjustments
- net profit

Cash basis P&L can be added later if needed, but cash received should initially
be a separate report.

### Job Profit

Job profit should use accrual revenue by default.

Formula:

```text
job profit =
  invoiced revenue
  - credit notes
  - write-offs
  - direct job costs
```

Payments should be displayed but not used to calculate profit. A job can be
profitable and still unpaid.

Receipts should be included in job profit when they are linked to the job. If a
receipt is linked to task items, the report should attribute the cost to those
task items. If a receipt is linked only to the job, the report should show it as
an unallocated job cost.

Tool purchases need special handling:

- tools bought for a specific job can be treated as direct job cost if that is
  how HMB records the task item
- tools bought for stock or long-term use should not automatically reduce one
  job's profit
- stock/tool receipts should appear in supplier spend and cash reports, and only
  enter P&L/job profit when expensed or consumed

Job profit output:

- quoted amount
- invoiced revenue
- credit notes
- adjustments and write-offs
- payments received
- outstanding debtor balance
- labour cost
- material cost
- supplier cost
- tool or consumable cost
- gross profit
- margin percentage

The report should support drill-down to:

- invoice lines
- task items
- payments
- credit notes
- adjustments

### Aged Receivables

Buckets:

- current
- 1-30 days
- 31-60 days
- 61-90 days
- 90+ days

Group by:

- customer
- contact
- job
- invoice

Show:

- invoice total
- allocated payments
- allocated credits
- adjustments
- outstanding balance
- due date
- days overdue

### Debtor Statement

Statement output:

- opening balance
- invoices
- credit notes
- payments
- adjustments
- closing balance

Filter by:

- customer
- contact
- date range
- job

### Cash Received

Cash received is payment-based, not invoice-based.

Output:

- payment date
- customer/contact
- payment method
- reference
- amount received
- invoice allocations
- unapplied amount

### Supplier Spend

Supplier spend is receipt-based.

Output:

- supplier
- receipt date
- job
- total excluding GST
- GST
- total including GST
- linked task items
- linked tools
- receipt photos

This report is useful even before full accounts payable support exists.

### Unreceipted and Unlinked Costs

This report highlights data quality issues that affect P&L and job profit.

Show:

- completed buy-type task items without a linked receipt
- receipts not linked to task items or tools
- receipts linked only to a job
- receipt totals that differ materially from linked task item expected costs
- tools with cost but no receipt

### GST Summary

GST reporting should use both sales and purchase sources.

Sales side:

- invoice GST collected
- credit note GST reductions

Purchase side:

- receipt GST paid
- purchase adjustments

Output:

- GST collected
- GST paid
- net GST
- source drill-down

## UI Changes

### Existing Operational Surfaces

HMB already has operational invoice surfaces that should be retained and
enhanced rather than duplicated.

Current surfaces:

- Accounting dashboard `To Be Invoiced` dashlet.
- Accounting dashboard `Invoices` dashlet.
- Main dashboard `Accounting` dashlet.
- Today page `Invoicing` section.
- `To Be Invoiced` screen.
- Invoice list screen.

Current behavior:

- the Accounting dashboard `To Be Invoiced` dashlet uses
  `DaoJob.readyToBeInvoiced` and estimates the unbilled amount from job
  statistics
- the Today page combines jobs ready for invoice creation with unsent invoices
  from `DaoInvoice.getUnsent`
- the invoice dashlet summarizes outstanding, paid, overdue, and 7+ day overdue
  invoice counts
- the main Accounting dashlet reuses the invoice count summary and can surface
  accounting sync warnings

The debtor accounting implementation should upgrade the data behind these
surfaces:

- replace `invoice.paid` checks with ledger-derived balance/status
- count `part_paid` invoices as outstanding until their balance is zero
- treat credit-only and written-off invoices according to derived status
- keep deleted and voided invoices excluded from normal operational counts
- add total outstanding value, not just counts, where space allows
- include unapplied payments and credits as warnings or secondary counts
- keep sync warnings visible on the Accounting dashboard and main Accounting
  dashlet

The existing routes should remain the entry points:

- `/home/accounting`
- `/home/accounting/to_be_invoiced`
- `/home/accounting/invoices`
- `/home/today`

New reporting screens should be added under Accounting, but operational alerts
should continue to live in these existing dashboard and Today surfaces.

### Job-First Money View

The job screen should be the primary place a tradie checks whether a job is
financially under control.

Show a compact money summary:

- to invoice
- invoiced
- received
- still owed
- supplier receipts and material costs
- labour or time cost where available
- profit
- margin

Actions:

- create invoice
- send/open invoice
- record payment
- add supplier receipt
- create credit
- write off balance
- view statement
- view profit detail

The user should not need to open a formal report to answer "did this job make
money?".

### Invoice Details

Add debtor accounting actions:

- record payment
- allocate existing payment
- create credit note
- apply credit note
- add adjustment/write-off
- view debtor history
- view sync status

Show:

- invoice total
- paid amount
- credited amount
- adjusted amount
- outstanding balance
- derived status

Fast path:

- `Record payment` defaults to the outstanding invoice balance.
- payment date defaults to today.
- payment source defaults to the last-used method.
- if the amount is less than the balance, save as `Part paid` without extra
  prompts.
- if the amount exceeds the balance, show a clear choice:
  - leave the extra as unapplied payment
  - allocate it to other invoices for the same customer
  - reduce the amount

Split allocation should exist, but it should not slow down the common case of
recording payment for one invoice.

Credit actions should be guided:

- discount remaining balance
- refund or credit customer
- fix invoice mistake
- write off balance

The UI can create the correct credit note, allocation, or adjustment behind
these actions.

### Invoice List

Replace paid-only filtering with balance/status filters:

- outstanding
- part paid
- overdue
- paid
- credited
- written off
- voided
- externally synced
- sync errors

The invoice list remains the drill-down target for the Accounting and main
Accounting dashlets.

### To Be Invoiced

The existing `To Be Invoiced` screen remains the action list for creating
invoices.

Enhance it to show:

- uninvoiced job/task value
- unbilled completed labour
- unbilled completed materials
- unbilled receipt-backed costs
- unsent invoice warning
- unlinked receipts for that job
- existing draft/unsent invoice actions

It should not become an aged receivables report. Once an invoice is sent, debtor
follow-up belongs in invoice/debtor views and overdue dashboard summaries.

### Money Today

The current Today page should remain the daily operational queue. The money
items in Today should be short and action-oriented rather than report-like.

Show:

- jobs needing invoice creation
- unsent invoices
- invoices due today
- overdue invoices
- payments or credits needing allocation
- supplier receipts missing job/task links
- sync issues that need attention

Actions should be one tap where possible:

- add invoice
- open/send invoice
- record payment
- allocate payment or credit
- link supplier receipt
- open sync issue

### Customer or Debtor Screen

Add:

- customer balance
- unpaid invoices
- unapplied payments
- unapplied credits
- statement action

Customer statements should be simple and quick to send. A useful first release
is a one-tap statement from the customer or job context with a date range
defaulting to recent activity plus all open balances.

### Reports Screen

Add reports:

- profit and loss
- job profit
- aged receivables
- debtor statement
- cash received
- supplier spend
- unreceipted and unlinked costs
- GST summary

Reports should support export to PDF and CSV.

## Categories and Accounts

Avoid full chart-of-accounts complexity in the first user-facing release.

Use simple HMB categories:

- labour
- materials
- tools
- consumables
- subcontractor
- fees
- adjustment
- write-off
- other

When Xero or another accounting system is enabled, map these simple categories
to external account codes in integration settings.

The user should not need to pick accounting accounts during common job, invoice,
payment, or receipt workflows unless they have enabled advanced accounting
options.

## Warnings

Warnings should be sparse and actionable.

Warn when:

- an invoice is overdue
- a payment exceeds the outstanding balance
- a credit or payment is unapplied
- a supplier receipt is not linked to a job, task item, or tool
- a receipt total differs materially from linked task item costs
- HMB and Xero disagree on invoice/payment/credit state
- a job appears profitable on paper but has unpaid invoices

Avoid warning for normal partial payments, simple credits, or ordinary invoice
creation.

## Migration and Backfill

Migration should:

- add ledger, payment, credit note, allocation, adjustment, and external link
  tables
- create debtor transaction rows for existing invoices
- convert existing `paid = 1` invoices into synthetic payment records or
  closing adjustments
- preserve existing Xero invoice IDs
- populate `external_accounting_link` from existing invoice external fields
- keep existing invoice fields during the transition
- preserve existing receipts and `receipt_task_item` links
- avoid creating debtor ledger entries for receipts
- optionally create report-only purchase cost rows from existing receipts if a
  reporting cache is introduced

Backfill must be idempotent or guarded so it cannot duplicate ledger entries.

## Testing Plan

DAO and service tests:

- existing invoice creates debtor transaction
- partial payment leaves invoice part paid
- multiple payments fully pay one invoice
- one payment split across multiple invoices
- overpayment leaves unapplied balance
- credit note reduces invoice balance
- one credit note allocated across multiple invoices
- write-off clears invoice balance
- Xero payment import creates payment and allocation records
- Xero credit note import creates credit and allocation records
- migration backfills existing unpaid and paid invoices correctly

Reporting tests:

- P&L for month
- P&L for quarter
- P&L for financial year
- P&L for custom range
- credit notes reduce revenue in the correct period
- payments do not affect accrual P&L
- cash received report uses payment date
- job profit includes direct costs and excludes unpaid status from profit
- receipts feed purchase costs by receipt date
- linked receipt task items are not double-counted with task item actual costs
- unlinked receipts appear as unallocated job costs
- stock/tool receipts do not automatically reduce customer job profit
- GST summary includes receipt tax as GST paid
- aged receivables buckets invoices by due date and balance

## Phased Implementation

1. Add debtor ledger schema, entities, DAOs, and migrations.
2. Backfill existing invoices into the ledger.
3. Add ledger service and derived invoice balance/status logic.
4. Add manual payments and payment allocations.
5. Add credit notes and credit allocations.
6. Add adjustments and write-offs.
7. Add purchase cost service over existing receipts and task item links.
8. Upgrade existing Accounting dashboard, Accounting dashlet, Today invoicing
   list, To Be Invoiced screen, and invoice filters to use debtor status.
9. Extend Xero sync for payments, credit notes, and allocations.
10. Add aged receivables and debtor statement reports.
11. Add supplier spend, GST summary, and unlinked cost reports.
12. Add P&L, cash received, and job profit reports.
13. Add receipt lines or receipt allocations if header-level receipts are too
    coarse for accurate reporting.
14. Add PDF/CSV export where useful.

## Open Decisions

- Whether to keep `invoice.paid` permanently as a cache or remove it later.
- Whether P&L should support cash basis in the first reporting release.
- Whether write-offs should create credit notes, adjustments, or distinct
  write-off documents.
- How strict HMB should be when local and Xero allocations disagree.
- Which expense sources are complete enough for first-release P&L.
- Whether job profit should include estimated costs when actual costs are
  missing.
- Whether receipts need line-level entry in the first reporting release.
- Whether receipt sync to Xero should create bills, spend money transactions, or
  remain reporting-only.
- Whether tool purchases should be expensed immediately, capitalised, or
  allocated to jobs only when consumed.
- Whether to add a separate `Money Today` label or keep these action items under
  the existing Today page `Invoicing` section.
- Which simple HMB categories should be mandatory before mapping them to Xero
  account codes.
