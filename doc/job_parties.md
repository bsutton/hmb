# Job parties and focused editors

Existing jobs open on a summary card. Each section has its own editor and saves
independently; cancelling a section does not write its draft. Saving a section
reloads the job in a transaction and updates only that section's fields. Job
actions still go through the lifecycle state machine. The job list's dashlets
are unchanged.

## Contacts and roles

A party assignment is one contact and one role on one job. A contact can have
multiple roles, but duplicate contact/role pairs are rejected. Primary Contact
and Billing Contact are singletons; replacing either requires confirmation.

Standard roles are Primary Contact, Billing Contact, Site Contact, Project
Manager, Referrer, Owner, Tenant, Body Corporate Manager and Authoriser. Their
names cannot be edited or deleted. Users may create and rename custom roles;
an in-use role must be reassigned before it can be deleted. Authoriser records
the person's job role; it does not bypass approval or lifecycle controls.

A contact's default role suggests a role when adding them to a job. It never
changes existing job assignments.

## Billing

A job has one Bill To customer. Splitting a bill still means splitting the job,
not assigning different billing customers to tasks.

For new arrangements the recipient is resolved in this order:

1. The job's explicit Billing Contact.
2. The Bill To customer's default billing contact.
3. The job's Primary Contact.
4. The only distinct contact assigned to the job, even if they have several roles.
5. No recipient: select a billing contact before sending the invoice.

The summary displays the effective customer, recipient and source of any
automatic selection. Choosing a Billing Contact can default Bill To from their
single customer link, but does not replace an explicitly chosen Bill To.
An explicit invoice recipient can differ from the billed customer.

## v213 migration and compatibility

- Distinct trimmed, case-insensitive contact role descriptions become role
  records. Exact standard-name matches use the standard role; other names become
  custom roles. No semantic aliases or authority are inferred.
- Contact defaults reference `contact_role`. The old `role_description` column
  remains a canonical display cache maintained by the DAOs, not editable free
  text.
- `job.contact_id` maps to Primary Contact, not Site Contact. Explicit billing,
  referrer and tenant contact fields map to their corresponding assignments.
- The old job contact fields remain compatibility projections for existing
  callers, including primary-contact phone/email/quote handling. Assignment
  changes update these projections transactionally. Unrelated job updates do
  not remove custom or multiple-role assignments.
- Customer, referring customer and site links are retained even when they have
  no contact. The existing customer/referrer billing choice seeds Bill To.
- The legacy resolver's actual recipient is preserved on migrated jobs and
  labelled as such. A deliberate recipient/customer change clears that preserved
  choice; changing only rates does not. The billing editor also offers an
  explicit "Use current defaults" action, applied only when the editor is saved.
- Existing invoice recipients are retained. Missing recipients are populated
  from the preserved arrangement, and the billed customer is recorded on the
  invoice. New invoices also save their recipient and billed customer. Later
  job changes do not redirect those invoices. Existing payment and ledger rows
  are not rewritten by this migration.

The migration is exercised against a synthetic v212 SQL fixture, including
repeat upgrade handling and foreign-key checks. Production databases and
customer data are not test fixtures.
