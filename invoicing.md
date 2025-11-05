# Invoicing

Invoicing in HMB is probably the most complicated aspect of the system.

This document attempts to define the set of rules we use when generating invoices.


# Use cases

## Fixed price
The user creates estimates via Tasks and Task Items, estimating each task item to be purchased or supplied plus doing labour estimates.
A quote is generated with the option of directly invoicing or creating milestones as agreed with the customer.
The user may choose to record actual costs against Task Items and track their time but these values are ignored
when generating quotes or invoices.
If directly invoicing (without a quote) we should allow the user to select which tasks to invoice - this becomes a pseudo milestone
without actually creating milestones.
In this case we need to be able to mark the task as having being 'billed'.
If a milestone exists we shouldn't allow the user to directly create an invoice (unless it is mixed billing as below)

### Quoting
Problem: we currently allow multiple quotes to exist for a Job. This is necessary as a quote may be rejected - at which point the user
may create a new quote which is then accepted.
When accepting a quote for a job - we should mark all other quotes as rejected.


## Time and Materials
The user creates Tasks and Task Items as needed. 
The user may not create a Task Item of type 'Labour' as the labour costs are done via tracking hours.
A user may enter estimates for Task Items but these are ignored, only the Actual costs are used when invoicing.

The user may generate an invoice at any point in the during the job and cumulated hours and task items are added to the invoice 
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
When selecting tasks - if an (accepted) quote exists that is associated with a task 

#### Quoting
We do not allow a quote to include T&M tasks.

What happens if the user changes the billing type of a task after we have quoted and the quote includes the task.
I think that if a Task appears in an quote (unless the quote has been rejected) then you can not change the task type to T&M.

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
For each job multiple quotes may be on-foot.

This allows the user to create quotation variants for a job
e.g. one quote includes painting and the other doesnt.

If a job is rejected than all associated quotes are rejected.


# jobs
If a job is rejected then all quotes are rejected.
We don't alter the state of task or task items in case the job becomes active again. In this 
way, any individual task that had originally been rejected remain rejected after activation which is the most likely
use case - maybe we should warn the user that some tasks are currently marked as 'rejected'.

## Billing Types
HMB supports three billing Types
* Time and Materials
* Fixed Price
* Non-billable.

Billing Types are cascaded from the Job to the Task

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

Task Items drive both quoting and invoicing. The following notes capture the current behaviour in code.

## Charge modes and margins
- `ChargeMode.calculated` adds the item's margin to the total line cost (quantity * unit cost) with the margin applied at the line level so rounding stays consistent.
- `ChargeMode.userDefined` stores the entered line total and ignores the cost inputs when invoicing.
- Recording actuals on a T&M material item (marking it completed) recalculates the line total from the captured quantity/unit cost and flips the item to user defined so the invoiced value remains fixed.
- Manual charge entry is available in the UI via "Enter charge directly", which simply toggles the stored charge mode.

## Billing type behaviour
- **Fixed Price jobs**: materials always use the estimated quantity and unit cost; actuals are only kept for P&L. Labour Task Items respect their entry mode, either estimated hours * job hourly rate or the estimated labour cost, and margins apply only when the item remains calculated.
- **Time & Materials jobs**: completed Task Items invoice off actual quantity and unit cost; before completion we fall back to estimates. Labour Task Items are ignored for billing (LabourCalculator returns zero) because labour is billed from time entries, and the UI prevents creating them in this context.
- **Non-billable work**: charges are forced to zero even though we retain the underlying costs internally.
- Quote and invoice builders evaluate Task Items using the job-level billing type. The specification calls for mixed billing (task-level overrides), so invoice and quote generation must be updated to honour the task's effective billing type.

## Completion, invoicing and returns
- Only completed, unbilled Task Items are considered for invoicing. Items of type labour or tools-own, and any item whose calculated charge is zero, are skipped.
- Returns reuse the same calculators but negate the cost and charge so the invoice gets a credit line.
- When a Task Item is billed we persist the `invoice_line_id`; undoing billing requires clearing that link (e.g. by voiding the invoice line).
 
# Handyman Business App — Invoicing & Billing Specification

_Last updated: 2025-02-xx_

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
- **One quote may be accepted per job**
- Quote variants permitted, but only **one can be accepted**
- If multiple disjoint scopes exist → **split into multiple jobs**
- Booking fee billed **once only**

---

## 2. Use Cases

### UC-FP-1 — Fixed Price: Quote → Milestones → Invoice(s)
1. Create Tasks and estimated TaskItems
2. Generate quote
3. Customer approves
4. Create milestones (or invoice 100% if allowed)
5. Generate invoices per milestone
6. FP TaskItems marked billed

**Guard:** Direct invoicing on FP job is blocked once quote approved.

---

### UC-FP-2 — Fixed Price (No Quote)
- Used for small jobs or urgent agreements
- User selects FP tasks → creates invoice
- Acts like a “pseudo-milestone”

**Guard:** If quote approved or milestones exist → disallow.

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

### UC-VAR-1 — Quote Variants
- User may prepare multiple scenario quotes
- On approval of one, system auto-rejects others

Shared tasks allowed, but **only one accepted quote total**

---

### UC-SPLIT-1 — Job Split Enforcement
If user tries to quote disjoint scopes:
> Require separate jobs

System prompt:
> _“This quote contains unrelated scopes. Create multiple jobs.”_

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
| FP | First quote or first FP invoice |

After billing → `booking_fee_invoiced = true`

---

## 3. Task Editing Rules

### After Quote Approval
| Action | Allowed |
|--------|--------|
Add new FP task | ❌ Block — instruct to split job or reject quote & re-quote |
Edit FP task | ❌ Block |
Edit labour TaskItems on FP task | ❌ Block |
Edit material/consumables tools on FP task | ✅ Allowed |
Edit FP task **internal notes only** | ✅ Allowed |
Add T&M task to mixed job | ✅ Allowed |

**User messaging:**
> _“Quote approved. To change fixed-price scope, reject quote and create a new one.”_

---

## 4. Billing Type Inheritance

| Value in DB | Meaning |
|-------------|--------|
`NULL` | Inherit job billing type |
Explicit value | Task override |

Effective billing:


UI displays **“Inherited”** when value is `NULL`.

---

## 5. Quote Rules Summary

- No per-line rejection
- Approved quote ≠ editable
- Revision = **Reject quote → new quote**
- Unique quote number always
- Quote variants allowed; only one selectable
- Disallow adding FP tasks post-approval

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
- Only editable FP field after approval: `internal_notes`

### TaskItem
- Column renamed: `total_charge → total_line_charge`

---

## 8. UI Requirements

- Billing type dropdown displays **Inherited** when null
- Disallow FP task creation/edit after quote approval
- Provide CTA:
  - “Reject quote and revise”
  - “Create separate job”
- Warning on job reactivation if tasks rejected

---

## 9. SQL Migration Requirements

- Add `billing_type` to `task` (nullable)
- Migrate legacy values to explicit
- Rename task_item column → `total_line_charge`
- Default `margin` to zero if null during migration
- After backfill, allow NULL = inherited

---

## 10. Acceptance Tests

| Test | Result |
|------|--------|
Approve quote, add FP task | ❌ Disallowed |
Approve quote, edit FP task | ❌ Except internal notes |
Approve quote, edit material costs | ✅ Allowed |
Change FP→T&M after approve | ❌ Must reject first |
Reject quote → create new | ✅ New quote number |
Split job workflows | ✅ Separate jobs |
T&M invoice pulls actuals only | ✅ |
Booking fee billed twice | ❌ Prevented |

---
