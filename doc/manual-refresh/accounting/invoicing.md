# Invoicing

Open **Home → Accounting → Invoices** to create or review invoices. Job-specific
invoice actions provide another entry point. **To Be Invoiced** helps identify
unbilled work and missing billing setup.

Billing follows each task's effective type, not just the job default:

- Fixed Price uses agreed/estimated charges and quote scope rules.
- Time and Materials uses eligible recorded time and completed unbilled items.
- Non-billable work is not charged.

Review the selected tasks, billing contact, booking fee, materials and labour
grouping before creating a draft. For mixed jobs, only eligible scope is selected.
An approved quote with milestones uses milestone invoicing for its quoted scope;
unquoted work can remain eligible for direct invoicing.

The invoice stores its billing contact. Draft invoices allow **Change Contact**
and, when relevant, **Use Job Contact**. Sent/uploaded invoices show that contact
read-only. A missing email may allow a draft but prevents email delivery or
external upload until corrected. Keep a primary contact on the job as well:
View/Send checks for one in this version.

Use **View/Send...** to generate and review the PDF, then choose delivery. When
external accounting is enabled, the app requires upload before email delivery.
A generated PDF is not proof of successful email delivery or payment.

For locally tracked invoices, the details screen offers payment and adjustment
actions according to invoice state. Customer Payments lets you record and
allocate receipts of money. Review total, paid, credited, adjusted and balance
figures rather than treating “sent” as “paid”.

Use the available void/adjustment workflow to correct an invoice; do not assume
any invoice can simply be deleted and recreated. External deletion/void status
can block sending. External accounting records may require correction there.

See [Fixed Price](invoicing/fixed-price.md),
[Time and Materials](invoicing/time-and-materials-cost-plus.md) and
[Integration](invoicing/integration.md).
