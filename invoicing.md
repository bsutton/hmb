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
 
 