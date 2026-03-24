# Quoting

This document defines the intended quote lifecycle and scope rules for HMB.
It is a forward-looking specification and does not describe current behavior.

## Core model

- Quotes are only available for Fixed Price tasks.
- A job may contain a mix of Fixed Price, Time and Materials, and
  non-billable tasks.
- Job billing type is only a default. Task billing type controls whether a
  task is quoteable.
- Any job with at least one Fixed Price task may have a quote.
- At most one active/open quote stream may exist for a job at a time.

## Use cases

### Fixed Price task flow

- User adds one or more Fixed Price tasks to a job.
- The user estimates those tasks using Task Items and Labour estimates.
- The user generates a quote and sends it to the customer.
- The customer may approve, reject, withdraw, or request a revision.
- If a revision is required, the user must use the quote revision flow rather
  than editing the active quoted scope in place.
- If the customer wants alternate commercial options, create a separate job.
- Once the quote is approved, the user may create milestones or directly
  invoice quoted scope when milestone rules allow it.

### Estimation

- Quotes are built from task estimates, not actual costs.
- Fixed Price quotes use estimated quantities, estimated unit costs, and
  estimated labour.
- Actual costs and tracked time are retained for P&L, but do not affect the
  quoted amount.

## Quote lifecycle

Rule: a job may only have one active quote stream at a time.

- If a quote is approved, no new standalone quote can be created for that job.
- If a quote is rejected or withdrawn, a new standalone quote can be created.
- If a job is rejected, all associated quotes are rejected.
- Quote variations are handled either by quote amendments or by creating a
  separate job, depending on whether the change is a revision or an
  alternative option.
- When a user rejects a quote, prompt them to optionally reject the job.
- A quote may be rejected by the customer and a reason should be recorded.
- A quote may be withdrawn by the user and a reason should be recorded.
- A quote cannot be rejected or withdrawn if an invoice exists, unless that
  invoice is voided first.
- If a quote is rejected or withdrawn, associated milestones are removed.
- If a quote is rejected or withdrawn, the associated tasks may be modified.
- Fixed Price tasks that have already been invoiced cannot be included in a
  new active quote or amendment.

## Scope control

- While a quote is active, associated tasks and task items cannot be mutated
  in a way that invalidates the quoted document.
- Task items associated with an active quote may not have their estimated
  charges edited.
- Task items associated with an active quote may not be deleted.
- Quotes ignore Task Item actual costs and tracked time.
- Post-approval task additions are allowed, but they are unquoted until
  explicitly included by amendment or separately invoiced.

## Quote amendments

Quote amendment is the preferred mechanism when the customer is still working
through the same commercial agreement, but the Fixed Price scope changes.

### Intent

- Preserve continuity between the original quote and its revisions.
- Prevent users from manually juggling quote rejection and quote recreation.
- Keep scope changes explicit and reviewable.

### Rules

- An amendment belongs to an existing quote stream.
- An amendment may add new Fixed Price tasks and may mark previously quoted
  scope as rejected or superseded.
- An amendment may not include tasks already present on another active quote
  or amendment.
- An amendment may not include tasks that have already been invoiced.
- If an existing quoted task needs to change materially, the user should copy
  it, revise the copy, and use the amendment to replace the earlier version.
- In some cases the replacement scope may move to Time and Materials; that
  should be explicit in workflow and pricing, not hidden inside the original
  quote.

### Lifecycle

- Amendments go through the same lifecycle as the base quote:
  send, approve, reject, withdraw.
- The quote stream should preserve history so users can see what changed and
  why.

### Milestones and invoicing

- Milestones should attach to the quote stream, not just a single quote part.
- Milestone totals should reflect the aggregate approved quote state across
  the base quote and approved amendments.
- If quoted scope is cancelled or reduced by amendment, the system should warn
  when existing milestones now exceed the revised quoted amount.
- That warning should continue until milestone totals are reconciled.

### Presentation

- Users should be able to open a quote stream and clearly see:
  original quote, amendments, current effective scope, and superseded scope.
- Sending should support:
  - the current quote part only
  - the aggregate quote stream
  - a consolidated current-state quote that collapses superseded history

## Relationship to invoicing

- Quotes govern Fixed Price scope only.
- Time and Materials tasks are never quoted.
- Invoicing rules, milestone rules, and direct-invoice rules live in
  [invoicing.md](/home/bsutton/git/hmb/doc/invoicing.md).

## Current implementation review

The current amend flow implemented for issue `#326` is a lightweight
replacement-quote flow, not a full quote amendment stream.

What it currently does well:

- Creates the replacement quote and rejects the original in one transaction.
- Reduces operator error compared with asking the user to reject and recreate
  manually.
- Keeps the user focused on selecting replacement scope rather than managing
  quote state themselves.

What it does not yet implement from the intended model:

- No persistent parent/child relationship between original quote and amended
  quote.
- No shared quote number with amendment part numbering.
- No stream-level view of superseded and current scope.
- No aggregate milestone handling across the quote stream.
- No support for sending a single amendment, aggregate stream, or consolidated
  current-state quote.
- No explicit representation of rejected line items within a quote stream.

## Recommended process direction

If the product goal is only "make revision easier", the lightweight flow is
acceptable:

- Reject old quote.
- Create replacement quote in one transaction.
- Treat the new quote as the sole active commercial document.

If the product goal is "track negotiated quote history and revisions as one
commercial thread", the current flow is insufficient and the model needs:

- explicit quote stream identity
- amendment linkage
- superseded scope tracking
- stream-level milestone and send behavior

## Open decisions

1. Is an amendment just a convenience action that replaces the prior quote, or
   a first-class revision in a quote stream?
2. Do milestones belong to a single approved quote, or to the full quote
   stream?
3. Should customers receive one current-state document, or a history of base
   quote plus amendments?
4. When scope is removed, do we model that as rejected tasks, superseded
   tasks, or both?
