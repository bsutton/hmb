# QuickBooks Online export preview (#15)

This branch adds an explicit invoice export provider, separate from HMB's
existing Xero payment/lifecycle adaptor. It has not been authorized against a
live Intuit company. Do not treat mock tests as production certification.

## Setup

1. Create an Intuit developer app and sandbox company. Register a redirect URI
   under your control. Production requires HTTPS; sandbox permits localhost.
2. Open Settings → Integrations → QuickBooks. Enter the app client ID and secret,
   redirect URI, and the company's product/service item ID and sales tax codes.
   The item determines the revenue account; no Xero account code is reused.
3. Leave Sandbox enabled until the acceptance checks below pass.
4. Connect, authorize with Intuit, and paste the final callback URL into HMB.
   This preview uses a manual callback rather than a hosted OAuth relay. Never
   paste the callback into support logs, chat, or a third-party callback service.
5. Open an invoice → QuickBooks export. Enter its QuickBooks customer ID,
   verify the returned customer name, and confirm export.

Client secrets and OAuth tokens use the platform secret store, not ordinary
system configuration or the SQLite settings table. Changing the app, redirect,
secret or environment invalidates local authorization. Disconnect removes local
tokens; revoke the app separately in Intuit if required.

## Behaviour and limits

- Export creates a snapshot. It does not synchronize subsequent edits, voids,
  payments or delivery status. Reconcile these in both systems.
- HMB makes no send-email request. Review company-side automations separately.
- Currency is preserved, not converted. HMB currently stores invoice amounts as
  AUD; a US company must support the actual invoice currency.
- Each line exports as one item with its final HMB amount, preserving discounts
  and rounding. Original quantity/rate breakdowns are not exported separately.
- US tax is split from inclusive HMB totals. Other companies use tax-inclusive
  amounts. Missing tax metadata, ambiguous zero-tax placeholders, and line/total
  mismatches are rejected. Advanced tax treatments and differing tax rates need
  a richer mapping before use; the preview has one taxable and one zero-tax code.
- The remote total is checked and stored. A mismatch requires review in
  QuickBooks, not another export.
- An export attempt stores its company, environment, payload and stable request
  ID before the network write. An unchanged retry reuses that ID. Changed
  content/company is refused. Do not delete that record to bypass reconciliation.
- Invoices with an export attempt cannot be deleted or subsequently uploaded
  through the Xero adaptor. Existing Xero-managed invoices cannot be exported.
- Customer selection is explicit by QuickBooks ID; no name-based auto-matching
  or automatic customer creation is performed.

## Live acceptance still required

- Sandbox authorization, rejected state/callback, token refresh and revocation.
- Correct item/account/customer mapping in the selected company.
- Taxable and exempt invoices, discounts, credits, progress invoices and mixed
  billing tasks; verify every total, currency and tax code in QuickBooks.
- Timeout/retry behaviour after remote creation, without duplicate invoices.
- Production credentials, redirect configuration and explicit authorization.
- Mobile callback usability and platform secure-storage behaviour.

These remain pending until an Intuit developer app and authorized company exist.
Automatic payment/lifecycle synchronization is not part of this preview.

References: [Intuit's OAuth setup example](https://github.com/intuit/quickbooks-online-mcp-server),
[tax-inclusive model](https://static.developer.intuit.com/sdkdocs/qbv3doc/ippdotnetdevkitv3/html/1b80a0bc-2f25-07bd-6cac-3a86e6c52498.htm),
and [request IDs](https://developer.intuit.com/app/developer/qbo/docs/learn/learn-basic-field-definitions#request-id).
