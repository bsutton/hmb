# Accounting UI Test Plan

This plan covers the whole accounting UI, not only the debtor accounting
enhancements. It is intended for Pixel 5/fdb manual testing and for later
conversion into widget/integration tests.

## Goals

- Prove the accounting dashboard routes are reachable and usable on a phone.
- Exercise the full debtor lifecycle: invoice, partial payment, split payment,
  credit note, write-off adjustment, overdue balance, paid balance, and
  statement output.
- Exercise supplier cost capture: receipts, job allocations, task-item links,
  and unlinked-cost reporting.
- Prove reports agree with the seeded ledger data for month, quarter, calendar
  year, financial year, and custom periods.
- Check that tax labels and calculations use configured tax settings rather than
  hard-coded GST assumptions.
- Capture rendering/log failures with `fdb logs` and `fdb syslog` after each
  route group.

## Test Data

Create a disposable dataset with names prefixed `UI Accounting Test` so it can
be found and removed later.

### Customers And Jobs

| Customer | Job | Purpose |
| --- | --- | --- |
| UI Accounting Test Alpha | Bathroom repair | unpaid and overdue invoice |
| UI Accounting Test Alpha | Kitchen touch-up | split customer payment |
| UI Accounting Test Beta | Deck repair | partial payment and write-off |
| UI Accounting Test Beta | Fence repair | credit note and statement |
| UI Accounting Test Cash | Small repair | fully paid invoice |

### Invoices

| Invoice | Job | Date | Due | Total | Expected state |
| --- | --- | --- | --- | ---: | --- |
| A1 | Bathroom repair | current month - 45 days | current month - 30 days | 100.00 | overdue |
| A2 | Kitchen touch-up | current month - 10 days | current month + 4 days | 150.00 | part-paid by split payment |
| B1 | Deck repair | current month - 20 days | current month - 5 days | 200.00 | 199.60 paid, 0.40 write-off |
| B2 | Fence repair | current month - 12 days | current month + 2 days | 120.00 | 25.00 credit note |
| C1 | Small repair | current month - 2 days | current month + 12 days | 80.00 | fully paid |

### Debtor Payments, Credits, And Adjustments

| Entry | Target | Amount | Purpose |
| --- | --- | ---: | --- |
| Payment P1 | A2 and C1 | 180.00 | split 100.00 to A2 and 80.00 to C1 |
| Payment P2 | B1 | 199.60 | underpayment by 0.40 |
| Adjustment W1 | B1 | 0.40 | small-balance write-off |
| Credit CN1 | B2 | 25.00 | goodwill credit |

### Supplier Receipts And Costs

| Receipt | Job allocation | Task-item link | Ex tax | Tax | Purpose |
| --- | --- | --- | ---: | ---: | --- |
| R1 | Bathroom repair 60.00 | linked | 54.55 | 5.45 | job profit cost |
| R2 | Kitchen touch-up 30.00, Deck repair 50.00 | no | 72.73 | 7.27 | split receipt and unlinked cost |
| R3 | no job | no | 20.00 | 2.00 | unlinked cost report |

### Settings

- Financial Year Start Month: set to July for period testing, then restore the
  original value after the pass.
- Tax label: verify the current configured label appears in Tax Summary. If the
  UI allows editing, temporarily use `VAT` or `Sales Tax` and confirm reports
  update, then restore the original value.

## Execution Checklist

Run these before and after each route group:

```bash
fdb describe
fdb logs --last 120
fdb syslog --since 10m --last 200
fdb syslog --since 10m --predicate "Exception" --last 100
```

For rendering issues, also inspect:

```bash
rg -n -C 20 "Exception caught by rendering library|RenderFlex|overflow|flutterError" .fdb/logs.txt
```

## Dashboard

- Open Home, then Accounting.
- Verify every dashlet is visible after scrolling: Estimator, Quotes, To Be
  Invoiced, Invoices, Milestones, Receipts, Cash Received, Tax Summary,
  Supplier Spend, Unlinked Costs, Aged Receivables, Statements, P&L, Job Profit.
- Verify dashlet values match the seeded data where a value is shown.
- Tap each dashlet and confirm it lands on the expected route and back
  navigation returns to Accounting.

## Invoices

- List shows unpaid, overdue, part-paid, credited, adjusted, and paid invoices.
- Search/filter controls do not hide valid seeded invoices unexpectedly.
- Invoice cards show total, balance, local/Xero sync state, and paid/overdue
  status correctly.
- Open each seeded invoice and verify debtor summary:
  - A1: balance 100.00, overdue.
  - A2: paid 100.00, balance 50.00, part-paid.
  - B1: paid 199.60, adjusted 0.40, balance 0.00, paid/write-off.
  - B2: credited 25.00, balance 95.00.
  - C1: paid 80.00, balance 0.00.
- Record Payment dialog:
  - rejects amount greater than balance.
  - accepts partial payment.
  - creates/updates debtor summary without requiring app restart.
- Write-Off dialog:
  - requires a reason.
  - writes off the remaining balance.
  - handles a 0.40 small-balance adjustment as a normal write-off.
- Invoice PDF preview opens and is readable on phone.
- Send invoice path handles missing email and valid email without crashing.
- Void/delete guards prevent unsafe deletion of invoiced/ledger-linked records.

## Receipts

- Receipt list shows supplier, job, ex-tax, tax, and inc-tax values.
- Create/edit receipt supports:
  - single job allocation.
  - split job allocation.
  - no job allocation.
  - task-item link where available.
- Verify the current legacy single-job display does not misrepresent split
  receipts; if it does, log the UX defect.
- Receipt photo/gallery area opens without rendering exceptions.
- Delete behavior protects linked receipts and updates reports after deletion.

## To Be Invoiced

- Seed at least one completed unbilled time/material task.
- Confirm the job appears with the expected billable amount.
- Create an invoice from selected tasks.
- Confirm billed task items disappear from To Be Invoiced and the new invoice
  appears in Invoices.

## Estimator, Quotes, And Milestones

- Estimator opens for seeded jobs and shows estimate totals.
- Quote list opens and quote total dashlet only includes sent/approved quotes.
- Quote-to-invoice path creates invoice lines with expected totals.
- Milestones list opens for fixed-price jobs.
- Editable milestones show invoice actions.
- Fully invoiced or voided milestones are not offered incorrectly.

## Reports

For each report, verify empty state, seeded state, CSV export, and PDF export.

### Cash Received

- Month view includes P1 and P2 payment totals.
- Split payment appears once in cash received, while allocations appear on the
  correct invoices/statements.
- Previous/next period excludes payments outside the selected range.

### Tax Summary

- Uses configured tax label in all headings.
- Invoice tax, credit tax, receipt tax, and net tax agree with seeded line tax.
- Shows explicit warning only where totals are estimated rather than line-based.
- Custom period, month, quarter, calendar year, and financial year boundaries
  include/exclude entries correctly.

### Supplier Spend

- Groups R1/R2/R3 by supplier.
- Shows ex-tax, tax, and inc-tax totals.
- Period changes alter totals correctly.

### Unlinked Costs

- Includes R2/R3 where not linked to task items.
- Excludes R1 when linked to a task item.
- Opens relevant receipt details from a row where supported.

### Aged Receivables

- Includes A1, A2, and B2 outstanding balances.
- Excludes B1 and C1 because their balances are zero.
- Buckets A1 into the overdue ageing bucket according to due date.
- CSV and PDF exports include the same balances as the screen.

### Statements

- All-customers statement includes all seeded debtor activity.
- Customer statement for Alpha includes A1, A2, and P1 allocation only.
- Customer statement for Beta includes B1, B2, P2, W1, and CN1.
- Job statement filters to the selected job only.
- Opening balance is correct when the period starts after invoice creation.
- View/Send opens the PDF preview.
- Missing email shows a non-blocking error and returns cleanly to the screen.

### P&L

- Income includes invoices.
- Credits and write-offs reduce income.
- Supplier receipts reduce profit.
- Month, quarter, calendar year, financial year, and custom periods match the
  seeded dates.
- CSV and PDF exports match on-screen totals.

### Job Profit

- Each seeded job can be selected.
- Bathroom repair shows invoice income and R1 cost.
- Kitchen touch-up shows part-paid state does not reduce invoice income, and R2
  split cost allocation is included.
- Deck repair shows write-off adjustment and R2 split cost allocation.
- Fence repair shows credit note reduction.
- CSV and PDF exports match on-screen totals.

## External Accounting Sync UI

- Invoices show local/managed-by-Xero state correctly.
- Existing external IDs/numbers are displayed where available.
- Sync warnings appear on Accounting dashboard when outbound/inbound sync fails.
- Local payments, credits, and allocations can be marked pending/synced/error in
  the UI once sync status controls exist.

## Pass Criteria

- No visible overflow, clipped action buttons, or unreachable controls on Pixel
  5 portrait.
- No new `sentry.flutterError`, render overflow, or route exceptions in fdb
  logs during the pass.
- Reports and debtor balances reconcile to the seeded data.
- Export and preview actions either succeed or show an actionable non-blocking
  error.
- Any missing UI capability is captured as a follow-up with route, screen text,
  screenshot path, and log excerpt.
