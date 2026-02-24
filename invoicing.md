# Invoicing

Invoicing in HMB is probably the most complicated aspect of the system.

This document defines the intended rules for the new invoicing implementation.
It is a forward-looking specification and does not describe current behavior.

Jobs have a 'default' billing type which is one of:
* Fixed Price
* Time and Materials
* Non-billable

The billing type at the Job level has no bearing on how a job is invoiced
rather the individual Tasks billing types control how billing proceeds.
The Job level billing simply acts as a default for each Task which the
user may override on a per task basis.

The abilty to raise quotes is only available if the Job contains at least
once Fixed Price task - via inheritance from the Job billing type or becuase
it is overriden by that Task.

Any Job with a Fixed Price Task (directly or inherited) may have one
active quote associated with it.



# Use cases

## Fixed price (FP) Tasks

The life cycle of a FP task is as follows:
- User adds one or more FP tasks to a Job.
- The user uses the Estimator tool to create an estimate of the Job, 
by adding FB Tasks and Task Items to those task with cost values for each
Task Item.
- The user generates a quote and sends it to the customer.
- The customer may approve, reject or request a revision of the quote.
- If a revision is required then a new quote must be created after
rejecting the active quote (only one active quote).
- If the customer wants alternate versions of the quote then a new job
must be created with the required variations. 
- Once the quote is approved the user may create milestones or directly invoice
the quote.
- The user may opt to not create a quote, in which case the tasks may be
directly invoiced across one or more invoices.


### Estimation
The user creates estimates via Tasks and Task Items, estimating each task item to be purchased or supplied and creating Labour based Task Items with estimates on 
an hourly or direct charge basis.

### Quoting
Rule: a job may only have one active quote at a time.
- If a quote is accepted, no new quote can be created for that job.
- If a quote is rejected or withdrawn, a new quote can be created.
- A rejected or withdraw quote may be accepted with a reason.
- A rejected/withdrawn quote may be accepted only when the job has no active quote and no
  accepted quote.
- If a job is rejected than all associated quotes are rejected.
- Quote variations are handled by creating a separate job.
- When a user rejects the quote - we should prompt them to 'reject' the job as well. 
- Quotes ignore any Task Item actual costs or tracked time. 
- If an active quote exists then the estimated charges for an Task Item associated
with the quote may not be edited. The actual costs may still be edited (for the purposes
of calculating the P&L on a project). 
Note: this will require us to display both the estimated qty/cost and the actual qty/cost.
- Task/Task Items associated with an active Quote may not be deleted.
- A quote may be rejected by the customer - a reason should be recorded
- A quote may be withdraw by the user - a reason should be recorded.
- A quote can not be rejected nor withdraw if an invoice exists unless that invoice
is voided.
- If a quote is rejected or withdrawn then the milestones are deleted.
- If a quote is rejected or withdraw then the tasks associated with that 
quote may be modified. 
- If a quote is rejected or withdrawn then it can not be re-approved to ensure
that the tasks are in sync with the quote, this ensures that both parties have an
authortive document.
- A quote may not include FP Tasks that have been invoiced

#### Alterations to quotes

If during a job the scope of a quoted FP Task is changed (or cancelled), then 
we allow the user to create a 'quote amendement'. 
A quote amendment is a quote which is linked to the original quote and shares the
same quote number but also has a part number.
An amendment may contain a list of rejected or new tasks.
As we don't allow a user to modify a task associated with an active quote, then
if the user needs to modify an existing task then they must copy the existing task,
update the new tasks estimates and then add it to the quote amendment.
In some cases the user may reject a tasks and create the new task as a T&M task.

The quote amendments will go through the same lifecycle as the quote (send,approve/reject/withdrawn).
The chain of quote amendments will share the same set of milestones as the original 
quote. This will require the milestone screen to calculate its totals from the agregate
set of quotes/amendments.
Clicking the Milestones or Invoices button on the The quote amendments card will take
the user to a Milestone screen which agregates the quote and amendments (it should clearly show this). 
Clicking the send button will give the user the option to send the 'currently selected  quote part' or an aggreate quote which will show the original quote plus each of the amendments. We also need to be able to produce a consolidated quote which collapses
out each of the amendments to show the quote as it stands now.

When a user goes to generate an invoice for a milestone and a quoted FP task has been
cancelled then we need to warn the user that they need to recreate the milestones.
We will still allow the user to generate the invoice, but will continue to warn them
each time they create an invoice from a milestone, until the milestones are equal to
or less than the revised quote.

A quote amendment may only include FP Tasks and may not include Tasks that 
appear on a active quote (or quote amendment) or which have been invoiced.


### Invoicing

#### FP Tasks
Fixed Price tasks are tasks that are done for a price agreed before the work
commences and normally go through an estimation/quote process.
We do however allow for a more informal process where by the quote is communicated
informally and accepted informally by the customer.  In these cases the 
Task is created an estimate recorded against it and at an agreed point an invoice
is generated against those tasks.

FP Tasks may be invoice directly or via milestones.
The user may choose to record actual costs against FP Task Items and track their time but these values are ignored when generating invoices.

##### Milestones
Milestones allow the user to generate invoices based on the progress of a job.
This will often include a deposit, zero or more progress payments and a final payment.

- Milestones may be drafted before quote approval to record payment discussions.
- A change to the quote, the rejection or withdrawal of a quote will cause
the milestones to be deleted.
- Milestones are not invoiceable until the quote is approved.
- If a Milestone exists then an Invoice may not be directly created unless
there are tasks that were created outside the scope of the quote and the Invoice(s)
are only for those out of scope tasks.
- If a quote is rejected or withdrawn then the milestones are deleted.

##### Direct Invocing
- If an invoice is directly created from the quote, then the user may choose which FP Task Items to invoice. Each FP Task Item may only be only be invoiced once (we mark these tasks as billed).
- If directly invoicing Tasks outside of the quote scope we should allow the user to select which tasks to invoice - this is a pseudo milestone invoice.
- The system will add jobs to the 'to be invoiced' list as long as there are
task outside the scope of a quote that have not been invoiced.
- If a milestone exists the user is NOT allowed to directly create an invoice
for quoted tasks. 
- New tasks added after the quote can be directly invoiced.
- If an active quote exists, the user will be warned (at the point they create any new tasks) that they will have to raise a direct invoice for thoses tasks as they are not covered by the quote. 


#### Time and Material (T&M) Tasks
The user creates Tasks and Task Items as needed as the job progresses. No
formal approval process is required.
T&M tasks are those tasks where the customer is billed based on the actual time
taken at an agreed hourly rate and cost of materials with an optional margin being applied to materials.

T&M tasks are not quoted.

T&M tasks may be invoiced progressively for both time and materials used.

When invoicing we allow the user to select which tasks to invoice. 

The user may not create a Task Item of type 'Labour' as the labour costs are done via tracking hours.
A user may enter estimates for Task Items but these are ignored, only the Actual costs are used when invoicing.

The user may generate an invoice at any point during the job and cumulated labour hours (tracked)
and task items (materials, consumables and tools - with a price), that are marked as complete are added to the invoice 
(then marked as billed).
The booking fee is only billed once for a Job.


#### Quoting
We do not allow a quote to include T&M tasks.

# jobs
If a job is rejected then all quotes are rejected.
When rejecting a quote, prompt the user to optionally reject the job.
We don't alter the state of task or task items in case the job becomes active again. In this 
way, any individual task that had originally been rejected remain rejected after activation which is the most likely
use case - maybe we should warn the user that some tasks are currently marked as 'rejected'.






## Task Items
We have a number of Task Item types.
Tools own - used to create packing lists and possibly charge customers a usage fee
Tools buy - used to create shopping list and possibly charge customers a usage fee
Materials stock - use to create packing list and possibly charge customres a fee
Materials buy - use to create shopping lists and normally charge customer a fee and possibly a margin.
Consumables stock - use to create packing list and possibly charge customres a fee
Consumables buy - use to create shopping lists and normally charge customer a fee and
possibly a margin.
Labour - used by FP Tasks only to create estimates.

### Labour
 - For Fixed Price Tasks we use them for estimating
 - For Time and Materials Tasks Labour items are not allowed, instead we use 
 time tracking to track actual hours.
 
 
### Estimates
 - Task Items (Tool, Materials and Consumables) are used to generate shopping/packing list. If attached to a FP Task then fees for these items go into quotes. 

### Actuals
Generally recorded at the time a Task Item is marked as complete. 
For FP Task these are used to calculate P&L.
For T&M Tasks these are used to generate the invoice, potentially with a margin
applied.


# Task Items & Pricing

Task Items drive both quoting and invoicing. The following notes capture the
intended behavior for the new implementation.

## Charge modes and margins
- `ChargeMode.calculated` adds the item's margin to the total line cost (quantity * unit cost) with the margin applied at the line level so rounding stays consistent.
- `ChargeMode.userDefined` stores the entered line total and ignores the cost inputs when invoicing.
- Recording actuals on a T&M material item (marking it completed) recalculates the line total from the captured quantity/unit cost and flips the item to user defined so the invoiced value remains fixed.
- Manual charge entry is available in the UI via "Enter charge directly", which simply toggles the stored charge mode.

## Billing type behaviour
- **Fixed Price jobs**: materials always use the estimated quantity and unit cost; actuals are only kept for P&L. Labour Task Items respect their entry mode, either estimated hours * job hourly rate or the estimated labour cost, and margins apply only when the item remains calculated.
- **Time & Materials jobs**: completed Task Items invoice off actual quantity and unit cost; before completion we fall back to estimates. Labour Task Items are ignored for billing (LabourCalculator returns zero) because labour is billed from time entries, and the UI prevents creating them in this context.
- **Non-billable work**: invoice charges are forced to zero even though we retain the underlying costs internally.
- Quote and invoice builders evaluate Task Items using the task's effective
  billing type (task override if set, otherwise job).

## Completion, invoicing and returns
- Only completed, unbilled Task Items are considered for invoicing. Items of type labour and any item whose calculated charge is zero, are skipped.
- Returns reuse the same calculators but negate the cost and charge so the invoice gets a credit line.
- When a Task Item is billed we persist the `invoice_line_id`; undoing billing requires clearing that link (e.g. by voiding the invoice line).
 
# Task-Driven Billing Specification

_Last updated: 2026-02-20_

## 1. Core Model

Billing is determined by each Task's effective billing type.

- Job billing type is only a default.
- Task billing type may override the job default.
- A mixed job is a normal case: some tasks may be FP, others T&M, others
  non-billable.
- Quotes are only for the Fixed Price tasks.

## 2. Canonical Invoicing Paths (Authoritative)

These rules apply no matter where invoicing is initiated:
- Quote card Invoice button
- Job | Invoices screen
- Accounts | Invoices screen

### 2.1 Fixed Price task scope

- FP Tasks attached to a quote requires an approved quote before invoicing.
- If an approved quote exists and no milestones exist, direct invoicing of
  quoted FP tasks is allowed.
- If milestones exist for that quote, quoted FP Tasks must be invoiced via
  milestones.
- FP tasks not in the approved quote are unquoted and may be invoiced directly.
- If blocked, the UI must explain why when the user clicks; do not silently
  disable invoice actions.

### 2.2 Time and Materials task scope

- T&M tasks are not quoted.
- T&M tasks may be invoiced progressively under T&M rules.
- In mixed jobs, T&M task scope remains direct-invoice eligible even when FP
  quote/milestone rules also exist for the same job.

## 3. Quote Lifecycle and Scope Control

- At most one active/open quote per job.
- A quote may have a stream of associated amendments
- If a quote is accepted, no new quote can be created for that job.
- If a quote is rejected or withdrawn, a new quote can be created.
- Quote variations are handled by quote amendments or separate jobs (per
  workflow choice).
- Quotes ignore Task Item actual costs and tracked time.
- While a quote is active, associated Task Items cannot be mutated in a way
  that invalidates the quoted document.
- If a quote is rejected/withdrawn, associated milestones are removed.
- If a quote is rejected, prompt to optionally reject the job.

## 4. Milestones

- Milestones may be drafted before quote approval for payment discussions.
- Milestones are not invoiceable until the quote is approved.
- If milestones exist, direct invoicing of quoted FP tasks is blocked.
- Direct invoicing of unquoted tasks is still allowed.

## 5. Task Editing and Billing-Type Changes

- Task/Task Item billing behavior always follows effective task billing type.
- Tasks in active quotes cannot be changed from FP to T&M without
  rejecting/withdrawing that quote first or creating a quote amendment that
  rejects the task.
- Post-approval task additions are allowed; added tasks are not attached
 to the quoted unless included by amendment.

## 6. Task Item Pricing Model

- `ChargeMode.calculated`: `cost x qty + margin` at line level.
- `ChargeMode.userDefined`: explicit line total entered by user.
- FP task invoicing uses estimated pricing fields for quoted tasks.
- T&M task invoicing uses T&M actuals fields.
- Returns create negative cost/charge lines.
- Billed Task Items have a non null `invoice_line_id`.

## 7. Booking Fee Rule

- Booking fee is billed once only per job (`booking_fee_invoiced = true` once
  posted).

## 8. Data Model Notes

### Task
- `billing_type` may be `NULL` (inherits job default)
- explicit value overrides job default



## 9. UI Requirements

- Billing type selector shows `Inherited` for `NULL`.
- Invoice actions enforce canonical rules consistently across all entry points.
- When an action is blocked, show a clear reason and next step.
- Surface quoted vs unquoted task scope in invoicing views.
- ability to copy a task and associated task items, tracked hours may be 'moved'
when a task item is copied.
 

## 10. Acceptance Checks

- Mixed jobs can invoice T&M tasks progressively while FP tasks follows
  quote/milestone/direct invoicing rules.
- FP task not attached to a quote can be directly invoiced.
- Approved quote + milestones blocks direct invoicing of quoted FP tasks.
- Unquoted tasks remain direct-invoice eligible.
- Changing quoted active FP scope requires quote lifecycle action first
  (reject/withdraw path).
