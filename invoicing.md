# Invoicing

Invoicing in HMB is probably the most complicated aspect of the system.

This document defines the intended rules for the new invoicing implementation.
It is a forward-looking specification and does not describe current behavior.


# Use cases

## Fixed price
The user creates estimates via Tasks and Task Items, estimating each task item to be purchased or supplied plus labour estimates.
A quote is generated with the option of directly invoicing or creating milestones as agreed with the customer.
Milestones can only be created from an approved quote.
The user may choose to record actual costs against Task Items and track their time but these values are ignored
when generating quotes or invoices.
If directly invoicing (without a quote) we should allow the user to select which tasks to invoice - this becomes a pseudo milestone
without actually creating milestones.
In this case we need to be able to mark the task as having being 'billed'.
If a milestone exists we shouldn't allow the user to directly create an invoice
for quoted tasks. New tasks added after the quote can be directly invoiced.
Once a milestone has been created, the user will be warned (at the point they create any new tasks) that they will have to
raise an invoice for thoses tasks as they are not covered by the milestones. If the user needs milestones for the new task the
user should create a new job (preferred), or invoice the added tasks directly if
they remain unquoted. If the user edits an existing task item (or adds or deletes) in a manner that affects the cost of the task (quantity, units)
then we must warn them that the adjustment cannot be billed and they should create a new task. We should still allow the user to save the edits,
but the quote remains the source of truth for billing and will not be updated.
as for example they may realize they need 5 posts not 4 and don't expect to bill the customer for the additional post.


### Quoting
Rule: a job may only have one open quote at a time.
- If a quote is accepted, no new quote can be created for that job.
- If a quote is rejected, a new quote can be created.
- A rejected quote may be accepted only when the job has no open quote and no
  accepted quote.

Quote variations are handled by creating a separate job.

When a user rejects the quote - we should prompt them to 'reject' the job as well. 


## Time and Materials
The user creates Tasks and Task Items as needed. 
The user may not create a Task Item of type 'Labour' as the labour costs are done via tracking hours.
A user may enter estimates for Task Items but these are ignored, only the Actual costs are used when invoicing.

The user may generate an invoice at any point during the job and cumulated labour hours (tracked)
and task items (materials, consumables and tools - with a price), that are marked as complete are added to the invoice 
(then marked as billed).
The booking fee is only billed once for a Job.

### Quoting
We do not allow quoting for a Time and Materials job.

## Mixed billing
It is often the case that a job has a mixe of Fixed Price and Time and Materials Tasks.

### Fixed Price job with T&M tasks.
In this scenario the user will initially quote the job, but then may agreed to do some tasks on a T&M basis.
The complication is at the point of invoicing.
With Fixed Price we allow the user to create milestones from a quote, or directly invoice.

When invoicing we allow the user to select which tasks to invoice. 
When selecting tasks - if an (accepted) quote exists that is associated with a task.

#### Quoting
We do not allow a quote to include T&M tasks.

A task billing type may not be modified if an non-rejected quote exists.
If a quote was rejected and then the customer tries to 'accept' the quote 
we inform the user that they must create a new quote. This will stop quotes
being generated that don't reflect the actually job estimates.

What happens if the user changes the billing type of a task after we have quoted and the quote includes the task.
I think that if a Task appears in an quote (unless the quote has been rejected) then you can not change the task type to T&M.

We have a problem in that task items are used for quoting and also purchasing.
The issues where we quote a customer for 4 posts but realize that we need 5 posts.
The nature of the quote (fixed price) is that we cannot recover the cost of the
additional post but we do need to update the task item as that feeds into our 
shopping list. 
Quotes do capture a snapshot of the tasks items at the point in time the quote 
was made so in once sense we can ignore changes to tasks and just treat them
as 'changes for shopping or other purposes'.  
This can make managing a job a little tricky when you get down to 'what did I 
quote vs what the tasks list has me doing'. This is normally fine until
the customer asks to add in additional task or extend an existing task
which then needs to be charged.  The correct approach is probably to tell 
the user to create a new job to track the additional work (preferred), while
still allowing direct invoicing for unquoted tasks added after acceptance. The issue is 
if we allow the user to modify quoted jobs, then there is no trigger to 
make them think to create a new job.
We could warn them on every change to task that has been quoted but this 
can get annoying very quickly and the users starts to ignore the warnings.


Scenario:
User created a fixed price task, quotes the job  but the customer rejects that one of the tasks and subsequently 
the user agrees with the customer to do it on a T&M basis. 


If the task is marked on the quote as rejected (but the rest of the quote is accepted) then we can allow the task billing
type to be changed to T&M.
We need to ensure that the user can't reverse the 'rejected' status on the quote.
Alternativly we could force the user to create a whole new quote - this might be simpler as then both parties
have an authoritive document as to what is agreed. 

So we provide a 'revise' button on the quote.

The process of 'revising' a quote 'rejects' the current quote and creates a new quote which can then be edited.
A quote can be edited until the point it has been sent, after which it can only be revised.

This might not be enough as the user may need to re-do some estimates before creating the new quote and the quote takes a 'snapshot' 
of the tasks at that point in time.

So I think we just need to reject a quote in total, the user then goes back into the estimate screen and marks the tasks as rejected changed
modifies any estimates and then generates a new quote.


# Quotes
For each job only one quote may be on-foot (open) at any time.

If a job is rejected than all associated quotes are rejected.


# jobs
If a job is rejected then all quotes are rejected.
When rejecting a quote, prompt the user to optionally reject the job.
We don't alter the state of task or task items in case the job becomes active again. In this 
way, any individual task that had originally been rejected remain rejected after activation which is the most likely
use case - maybe we should warn the user that some tasks are currently marked as 'rejected'.

## Billing Types
HMB supports three billing Types
* Time and Materials
* Fixed Price
* Non-billable.

Billing Types are cascaded from the Job to the Task. If a Task billing type is
set it overrides the Job billing type.

Question: What about task Items 

What are task items?
 - we use them to estimate labour (the labour type should only be selectable for Fixed Price Tasks).
 - otherwise we use them for shopping/packing list. The 'actual costs' flows through to invoices for T&M whlist the estimated costs
   are used to generate quotes for fixed price projects.

Task Items can define 'estimates' and 'actual' costs.

Estimates are used when doing estimates for a Fixed Price quote.
For T&M estimates can be left blank or entered 
 - may be we should disallow entering estimates for T&M.
 - what if the user wants to do a rough estimate for teir own purposes?
 
When an Item is purchased we save the cost in the actual field.
For T&M this actual value is used for invoicing.
For Fixed, we store the cost but this will only be used for calculating P&L on a job.



Should we need to allow an invoice to be generated directly from a Fixed Price job if no quote has been issued?
 - A user could agree to a fixed price whilst on the job, enter the estimates into a task and then directly create the invoice.


We need to allow an invoice to be created directly from an quote without creating milestones.
 - small fixed price jobs may be invoice 100% at start or at the end - particularly if this is for a regular client.
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
- **Non-billable work**: charges are forced to zero even though we retain the underlying costs internally.
- Quote and invoice builders evaluate Task Items using the task's effective
  billing type (task override if set, otherwise job).

## Completion, invoicing and returns
- Only completed, unbilled Task Items are considered for invoicing. Items of type labour or tools-own, and any item whose calculated charge is zero, are skipped.
- Returns reuse the same calculators but negate the cost and charge so the invoice gets a credit line.
- When a Task Item is billed we persist the `invoice_line_id`; undoing billing requires clearing that link (e.g. by voiding the invoice line).
 
# Handyman Business App — Invoicing & Billing Specification

_Last updated: 2026-02-06_

## 1. Overview

Invoicing in HMB supports three billing types:

| Billing Type | Usage |
|--------------|-------|
| **Fixed Price (FP)** | Quoted jobs with clear scope |
| **Time & Materials (T&M)** | Jobs billed by hours & actual materials |
| **Non-Billable** | Internal work or goodwill tasks |

### Key Principles
- Approved quotes **freeze scope and pricing**
- FP items use **estimates**
- T&M items use **actuals**
- Quotes **cannot be edited** after approval
- All quote changes require: **Reject Quote → Edit Job → New Quote**
- **At most one open quote per job**
- **If a quote is accepted, no further quote can be created for that job**
- **A rejected quote can be accepted only when no open/accepted quote exists**
- Booking fee billed **once only**
- Quote is the source of truth for FP billing. Post-quote edits do not change
  the final invoice for quoted tasks.

---

## 2. Use Cases

### UC-FP-1 — Fixed Price: Quote → Milestones → Invoice(s)
1. Create Tasks and estimated TaskItems
2. Generate quote
3. Customer approves
4. Create milestones (or invoice 100% if allowed)
5. Generate invoices per milestone
6. FP TaskItems marked billed

**Guard:** Direct invoicing of quoted FP tasks is blocked once quote approved.

---

### UC-FP-2 — Fixed Price (No Quote)
- Used for small jobs or urgent agreements
- User selects FP tasks → creates invoice
- Acts like a “pseudo-milestone”

**Guard:** If quote approved or milestones exist → disallow.

---

### UC-FP-3 — Fixed Price Additions After Quote
- Additional tasks may be added after a quote is accepted
- These tasks are not part of the quote
- They can be invoiced directly (no milestones required)
- They appear in the "To be Invoiced" view alongside other unbilled work

---

### UC-TM-1 — Time & Materials Invoice
- User logs hours + materials
- Invoice may be created at any time
- System includes **unbilled hours + unbilled actuals**
- Booking fee applied once (first invoice)

---

### UC-MIX-1 — Mixed Mode
- Some tasks FP, some T&M
- FP billed via milestones or pseudo-milestones
- T&M billed progressively

**Rule:** Quotes contain **FP tasks only**

---

### UC-MIX-2 — Change FP Task → T&M
After quote approved:
> FP tasks **cannot** be changed to T&M unless quote is rejected

Flow:
1. Reject quote (irreversible)
2. Edit job/task billing type
3. Create new quote

---

### UC-QUOTE-1 — Single Open Quote Lifecycle
- A job can have at most one open quote.
- Accepting a quote blocks creating additional quotes for that job.
- Rejecting a quote allows creating a new quote.
- A rejected quote may be accepted only when there is no open quote and no
  accepted quote for the job.

---

### UC-JOB-1 — Reject Job
Effect:
- All quotes rejected
- Tasks/items unchanged
- On reactivation → warn if tasks remained rejected

---

### UC-FEE-1 — Booking Fee Rules
| Job Type | When billed |
|---------|-------------|
| T&M | First T&M invoice |
| FP | First FP invoice (never at quote time) |

Rules:
- FP quotes include the booking fee line for visibility/pricing.
- A quote is not a payment request; only invoices request payment.
- Because only one open quote is allowed, we no longer support "quote series"
  booking-fee logic.
- Booking fee is posted once only when first invoiced, then
  `booking_fee_invoiced = true`.

---

## 2A. Quote State Table

| State | Meaning | Allowed transitions |
|------|---------|---------------------|
| Draft | Being prepared, not sent | Open, Rejected |
| Open | Active quote awaiting decision | Accepted, Rejected |
| Accepted | Contracted quote for the job | Rejected (customer rejects after acceptance; user must manually clean up) |
| Rejected | Not currently active | Accepted (only when no open/accepted quote exists), or remain Rejected |

Invariants:
- A job can have at most one Open quote.
- A job can have at most one Accepted quote.
- Create quote is allowed only when the job has no Open and no Accepted quote.
- Milestones can only be created from an Accepted quote.
- If an Accepted quote is later Rejected, any milestones created from that quote
  must be voided.

Voiding a milestone means:
- The milestone remains in history but is no longer invoiceable.
- The milestone is marked as voided and excluded from invoicing workflows.
- If a milestone has an `invoice_id`, it cannot be voided until the invoice is
  deleted or voided first.

If an Accepted quote is Rejected, this typically reflects a customer reversing
their decision after acceptance. The user must manually clean up any downstream
artifacts (invoices, milestones, task statuses). We may improve this later, but
for now the paths are too varied to automate safely.

---

## 3. Task Editing Rules

### After Quote Approval
| Action | Allowed |
|--------|--------|
Add new FP task | ✅ Allowed, but is not part of the quote |
Edit FP task | ✅ Allowed with warning |
Edit labour TaskItems on FP task | ✅ Allowed with warning |
Edit material/consumables tools on FP task | ✅ Allowed with warning |
Edit FP task **internal notes only** | ✅ Allowed |
Add T&M task to mixed job | ✅ Allowed |

**User messaging:**
> _“Quote approved. Changes to fixed-price task items will not change the quote
> or final invoice for quoted tasks. Consider reject + re-quote before
> invoicing.”_

---

## 4. Billing Type Inheritance

| Value in DB | Meaning |
|-------------|--------|
`NULL` | Inherit job billing type |
Explicit value | Task override |

Effective billing:
Task override if set, otherwise job billing type.

UI displays **“Inherited”** when value is `NULL`.

---

## 5. Quote Rules Summary

- Per-line rejection is allowed; rejecting a quoted line also rejects the task.
- A quote may still be accepted with some rejected tasks; rejected tasks are
  excluded from billing and remain rejected in the job.
- Approved quote ≠ editable
- Revision = **Reject quote → new quote**
- Unique quote number always
- At most one open quote per job
- Accepted quote blocks new quotes on that job
- Rejected quote may be accepted only if no open/accepted quote exists
- Adding FP tasks post-approval is allowed, but they are not part of the quote
  and can be invoiced directly (no milestones required).

---

## 6. TaskItem Pricing Model

- Line-level margin
- `total_line_charge` (renamed from `total_charge`)
- Two modes:

| Mode | Behavior |
|------|---------|
`calculated` | cost × qty + margin |
`userDefined` | user supplied total |

---

## 7. Data Model Key Notes

### Task
- `billing_type` may be `NULL` (inherited)
- Post-approval edits are allowed but do not affect quoted pricing

### TaskItem
- Column renamed: `total_charge → total_line_charge`

---

## 8. UI Requirements

- Billing type dropdown displays **Inherited** when null
- Allow FP task creation/edit after quote approval with warnings that changes
  will not affect the quote or final invoice for quoted tasks
- On quote rejection, prompt the user to optionally reject the job as well
- Provide CTA:
  - “Reject quote and revise”
  - “Create separate job”
- Warning on job reactivation if tasks rejected
- Add quoted vs unquoted tasks to "To be Invoiced" view, including new tasks
  added after a quote (unquoted tasks are direct-invoice eligible)

---

## 9. SQL Migration Requirements

- Add `billing_type` to `task` (nullable)
- Migrate legacy values with support for inheritance (`NULL`)
- Rename task_item column → `total_line_charge`
- Default `margin` to zero if null during migration
- Preserve existing explicit task billing overrides

Migration matrix:

| Legacy | New |
|--------|-----|
| Task has no explicit billing type column | `task.billing_type = NULL` (inherits job billing) |
| Task had effective billing type equal to job default | `task.billing_type = NULL` |
| Task had explicit override | Keep explicit `task.billing_type` |
| `task_item.total_charge` | `task_item.total_line_charge` |
| `task_item.margin IS NULL` | Set to `0` during migration |

---

## 10. Acceptance Tests

| Test | Result |
|------|--------|
Create second open quote while one is open | ❌ Disallowed |
Accept quote then create another quote | ❌ Disallowed |
Reject quote then create new quote | ✅ Allowed |
Accept previously rejected quote while another open quote exists | ❌ Disallowed |
Accept previously rejected quote with no open/accepted quote | ✅ Allowed |
Approve quote, add FP task | ✅ Allowed (unquoted, direct invoice) |
Approve quote, edit FP task | ✅ Allowed with warning |
Approve quote, edit FP task items | ✅ Allowed with warning |
Change FP→T&M after approve | ❌ Must reject first |
Reject quote → create new | ✅ New quote number |
T&M invoice pulls actuals only | ✅ |
Booking fee billed twice | ❌ Prevented |
FP booking fee present on quote, but not posted until invoice | ✅ |

---

## 11. Test Gaps (To Fill)
- Per-line rejection behavior and task rejection linkage
- Post-approval edits and warning flows
- Direct invoicing of unquoted FP tasks
- Milestones voided when an Accepted quote is later Rejected
- Cleanup requirements after customer rejection of an accepted quote
