# International Tax Reporting Plan

This document describes how HMB should support tax reporting across different
tax jurisdictions without hard-coding Australian GST assumptions.

It extends the debtor accounting design in `doc/debtor_accounting_design.md`.
The intent is to support English-speaking target markets such as Australia,
New Zealand, the United Kingdom, Canada, and the United States while keeping
HMB focused on handyman and sole-tradie workflows.

This is a product and technical design document. It is not tax advice.

## Goals

- Replace GST-specific reporting assumptions with a generic tax model.
- Keep the user experience simple for sole traders and small operators.
- Support standalone HMB reporting and future sync with external accounting
  systems such as Xero.
- Store tax explicitly on invoice and receipt lines rather than estimating tax
  from document totals.
- Allow country-specific labels and reports without changing the core ledger.
- Support cash and accrual reporting where the jurisdiction and user settings
  require it.

## Non-Goals

- HMB should not become a full tax compliance engine.
- HMB should not calculate every United States state, county, city, and special
  district sales tax rule in the first implementation.
- HMB should not submit official tax returns directly in the first
  implementation.
- HMB should not infer historical tax by dividing totals by a fixed GST factor.
- HMB should not hide the need for professional advice where tax rules are
  jurisdiction-specific.

## Jurisdiction Overview

The first implementation should support tax reporting patterns rather than
trying to encode every rule for every country.

### Australia

- Label: GST.
- Typical report: GST collected on sales, GST paid on purchases, net GST
  payable or refundable.
- Reporting periods commonly align with BAS periods.
- HMB should support cash and accrual basis.

### New Zealand

- Label: GST.
- Similar high-level reporting pattern to Australia, but rates, periods, and
  return labels differ.
- HMB should use country-specific labels and rates rather than Australian BAS
  language.

### United Kingdom

- Label: VAT.
- VAT reporting needs sales, purchases, VAT owed, VAT reclaimable, and net
  payable or reclaimable.
- UK VAT uses VAT return boxes and Making Tax Digital workflows. Initial HMB
  support should produce review/export reports rather than direct submission.

### Canada

- Label: GST/HST, with possible provincial differences.
- Reporting should support collected tax, input credits/reclaimable tax, and
  net payable or refund.
- Tax code setup must allow multiple rate names and effective dates.

### United States

- Label: sales tax.
- There is no federal GST/VAT equivalent.
- Sales tax may depend on state, county, city, customer location, job location,
  item/service type, and registration obligations.
- Initial HMB support should focus on recording collected tax and reporting it
  by configured jurisdiction, not automatically determining every liability.

## Design Principles

- Use `Tax` as the default UI word. Display GST, VAT, GST/HST, or sales tax
  only when derived from the configured tax scheme.
- Store tax at line level on invoices, credit notes, receipts, and adjustments.
- Store the tax code used at the time of the transaction so historical reports
  remain stable after settings change.
- Avoid tax calculations based only on invoice or receipt totals.
- Treat tax reports as derived reports over immutable financial events.
- Let settings define country, scheme, reporting basis, default rates, and
  labels.
- Let external accounting providers map local tax codes to provider-specific
  tax codes.
- Make unsupported or uncertain tax behavior explicit in the UI.

## Core Settings

Add or extend system settings with:

- `country_code`
- `tax_registered`
- `tax_scheme_id`
- `tax_reporting_basis`
- `financial_year_start_month`
- `financial_year_start_day`
- `default_sales_tax_code_id`
- `default_purchase_tax_code_id`
- `prices_include_tax`
- `tax_rounding_mode`
- `tax_report_period`

`tax_reporting_basis` should support:

- `cash`
- `accrual`

`tax_report_period` should support:

- monthly
- quarterly
- annually
- custom date range

## Proposed Data Model

Names are indicative. Final names should follow existing entity and DAO
conventions.

### `tax_scheme`

Represents a country or reporting style.

Fields:

- `id`
- `country_code`
- `code`
- `display_name`
- `tax_label`
- `supports_input_credits`
- `supports_jurisdiction_reporting`
- `created_date`
- `modified_date`

Example codes:

- `au_gst`
- `nz_gst`
- `uk_vat`
- `ca_gst_hst`
- `us_sales_tax`
- `custom`

### `tax_code`

Represents a selectable tax code or rate.

Fields:

- `id`
- `tax_scheme_id`
- `code`
- `display_name`
- `rate_basis_points`
- `tax_treatment`
- `jurisdiction_name`
- `effective_from`
- `effective_to`
- `external_provider`
- `external_tax_code`
- `is_default_sales`
- `is_default_purchase`
- `created_date`
- `modified_date`

`tax_treatment` should support:

- `taxable`
- `zero_rated`
- `exempt`
- `out_of_scope`
- `reverse_charge`
- `import`
- `manual`

Use basis points or another integer representation for rates. Do not store tax
rates as floating point numbers.

### `invoice_line_tax`

Stores tax calculated for an invoice line.

Fields:

- `id`
- `invoice_line_id`
- `tax_code_id`
- `taxable_amount`
- `tax_amount`
- `tax_inclusive`
- `created_date`
- `modified_date`

### `credit_note_line_tax`

Stores tax calculated for a credit note line.

Fields:

- `id`
- `credit_note_line_id`
- `tax_code_id`
- `taxable_amount`
- `tax_amount`
- `tax_inclusive`
- `created_date`
- `modified_date`

### `receipt_line_tax`

Stores tax calculated for a supplier receipt or purchase line.

Fields:

- `id`
- `receipt_line_id`
- `tax_code_id`
- `taxable_amount`
- `tax_amount`
- `tax_inclusive`
- `created_date`
- `modified_date`

If receipt lines are not implemented yet, add them before relying on purchase
tax reporting. Receipt-level tax can remain as a compatibility cache, but tax
reports should target line-level data.

### `tax_adjustment`

Records manual tax adjustments.

Fields:

- `id`
- `tax_scheme_id`
- `tax_code_id`
- `adjustment_date`
- `amount`
- `tax_amount`
- `reason`
- `notes`
- `created_date`
- `modified_date`

Use cases:

- rounding corrections
- bad debt adjustments
- small-balance write-offs with tax impact
- accounting-system sync corrections
- manual accountant-directed adjustments

## Calculation Rules

### Line-Level Calculation

For each taxable line:

- determine the tax code
- determine whether the entered price includes tax
- calculate taxable amount and tax amount
- store both values on the line tax table

For tax-inclusive prices:

- taxable amount is the tax-exclusive line amount
- tax amount is total line amount minus taxable amount

For tax-exclusive prices:

- taxable amount is the line amount before tax
- tax amount is calculated from the rate

Rounding must be deterministic and configured. The first implementation should
round per line because that is easiest to audit and sync. A later phase can add
document-level rounding if needed for a provider or jurisdiction.

### Cash vs Accrual Basis

Accrual basis:

- sales tax is reported by invoice or credit note date
- purchase tax is reported by receipt date

Cash basis:

- sales tax is reported when payment is allocated
- purchase tax is reported when a supplier receipt/payment is treated as paid

Cash basis requires allocation-aware tax reporting. For partial payments, tax
should be apportioned across paid invoice lines using a consistent rule.

Initial rule:

- allocate payment tax proportionally across the remaining taxable invoice
  balance
- store or derive the apportionment through payment allocation reporting
  services

## Reports

### Tax Summary

The generic tax report for all schemes.

Inputs:

- date range
- reporting basis
- tax scheme
- optional tax code
- optional jurisdiction

Outputs:

- sales excluding tax
- sales tax collected
- purchase excluding tax
- purchase tax paid or reclaimable
- net tax payable or refundable
- adjustments
- zero-rated, exempt, and out-of-scope totals

### GST Summary

Country-labeled view for Australia and New Zealand.

This is a presentation of the generic Tax Summary using GST labels.

### VAT Summary

Country-labeled view for the United Kingdom.

Initial output should align with the common VAT return concepts:

- VAT due on sales
- VAT due on acquisitions or special categories where supported
- total VAT due
- VAT reclaimed on purchases
- net VAT payable or reclaimable
- total sales excluding VAT
- total purchases excluding VAT

Do not claim official Making Tax Digital submission support until the required
API, audit, and digital-link requirements are implemented.

### GST/HST Summary

Country-labeled view for Canada.

Initial output:

- GST/HST collected
- input tax credits or reclaimable tax
- adjustments
- net payable or refund

### Sales Tax Liability

United States-oriented report.

Inputs:

- date range
- jurisdiction
- tax code

Outputs:

- taxable sales
- non-taxable sales
- exempt sales
- tax collected
- tax payable by jurisdiction
- source invoice list

Initial implementation should rely on configured tax codes and jurisdiction
fields rather than automatic tax-rate discovery.

### Tax Audit Detail

Lists every contributing line for a tax report.

Columns:

- date
- document type
- document number
- customer or supplier
- job
- line description
- tax code
- taxable amount
- tax amount
- reporting basis
- external accounting link

This report is essential for debugging differences between HMB and Xero.

## User Experience

### Settings

Add a Tax settings screen or section.

Fields:

- country
- tax registered toggle
- tax label preview
- default sales tax code
- default purchase tax code
- prices include tax toggle
- reporting basis
- financial year start
- reporting period

If `tax_registered` is false:

- invoices and receipts may still store tax code `out_of_scope`
- tax reports should show "Not registered for tax" and avoid payable language

### Invoice Lines

Each invoice line should show:

- tax code
- tax amount or inclusive indicator
- line total including tax

The default tax code should come from settings, but the user must be able to
override it.

### Credit Notes

Credit notes must carry tax code and tax amount per line. A credit note linked
to an invoice should default to the original invoice line tax treatment.

### Supplier Receipts

Receipt entry should support:

- supplier
- receipt date
- line items
- tax code per line
- tax-inclusive or tax-exclusive prices
- job allocation per line or allocation group

If receipt OCR extracts line items, extracted tax should be treated as draft
data requiring user confirmation.

### Reports

Use country-specific report labels, but keep navigation generic:

- Tax Summary
- Tax Detail
- Sales Tax Liability where applicable

Avoid hard-coded labels like `GST collected` unless the selected tax scheme is
GST-based.

## External Accounting Sync

External sync should map local tax codes to provider tax codes.

### Xero

Store Xero tax code mapping on `tax_code.external_tax_code`.

Sync requirements:

- outbound invoice lines include Xero tax code
- outbound credit note lines include Xero tax code
- outbound receipt or bill lines include Xero tax code when purchase sync is
  implemented
- inbound invoices and payments preserve tax code and tax amount where supplied
- conflict reports show line-level tax differences

Do not calculate Xero tax from HMB totals if Xero returns authoritative
line-level tax amounts. Store the provider result for reconciliation.

## Migration Strategy

### Existing Invoices

Existing invoices may not have explicit line-level tax.

Migration should:

- create default tax scheme from current system/country setting
- create default sales tax code
- backfill invoice line tax where safe
- mark inferred tax as inferred

If historical tax cannot be safely inferred, set line tax to manual review.

### Existing Receipts

Existing receipts currently have receipt-level tax values.

Migration should:

- keep receipt-level tax as a compatibility cache
- create receipt allocation records where needed
- create one receipt line for legacy receipts if no lines exist
- attach tax to that generated line
- mark generated line tax as inferred from receipt total

### Historical Reports

Reports should clearly distinguish:

- explicit line tax
- inferred line tax
- missing tax data

Do not silently mix inferred historical values with explicit new values without
showing a report warning.

## Implementation Phases

### Phase 1: Tax Settings and Codes

- Add tax scheme and tax code tables.
- Add default seed data for AU, NZ, UK, CA, US, and custom.
- Add system settings for country, registration, reporting basis, tax defaults,
  tax-inclusive prices, and financial year start.
- Add DAO/services for tax code lookup and date-effective rates.
- Add unit tests for tax code selection and date-effective behavior.

### Phase 2: Invoice and Credit Line Tax

- Add line-level tax tables for invoice and credit note lines.
- Update invoice generation to store explicit tax per line.
- Update credit notes to copy or select tax treatment per line.
- Update invoice and credit note UI to show/edit tax code.
- Add tests for inclusive and exclusive tax calculations.

### Phase 3: Receipt Line Tax

- Introduce receipt line items if not already present.
- Store tax per receipt line.
- Update receipt OCR/import workflow to capture draft lines and draft tax.
- Support job allocation per receipt line.
- Add tests for receipt tax and job-profit cost allocation.

### Phase 4: Generic Tax Reports

- Build Tax Summary and Tax Audit Detail reporting services.
- Support month, quarter, financial year, calendar year, and custom ranges.
- Support cash and accrual basis.
- Add warnings for inferred or missing tax data.
- Add export with report-specific filenames.

### Phase 5: Country-Labeled Reports

- Add GST, VAT, GST/HST, and Sales Tax Liability report views using the same
  underlying reporting services.
- Add country-specific labels and report sections.
- Keep unsupported official-return fields hidden until implemented.

### Phase 6: External Accounting Sync

- Add tax code mapping UI for Xero.
- Send local tax codes on outbound invoices, credits, and purchase documents.
- Store inbound provider tax amounts for reconciliation.
- Add tax difference report between HMB and external accounting provider.

### Phase 7: Review and Compliance Hardening

- Add audit trail for tax setting and tax code changes.
- Add lock dates for submitted/report-finalized periods.
- Add accountant review export.
- Add jurisdiction-specific validation rules where practical.

## Open Questions

- Should HMB ask for country during onboarding, or infer from locale and require
  confirmation?
- Should tax-inclusive pricing be global, per customer, or per invoice?
- Should HMB initially support receipt lines, or create a generated single line
  from the current receipt totals?
- Should US jurisdiction be selected manually per customer, per job, or per tax
  code in the first version?
- Should HMB keep local tax codes independent from Xero tax codes, or import
  Xero tax codes when sync is enabled?
- Should finalized tax periods prevent editing invoices and receipts, or allow
  edits only by creating adjustment documents?

## Recommended First Cut

Build a small but correct foundation:

1. Add tax scheme, tax code, and tax settings.
2. Add explicit invoice line tax and credit note line tax.
3. Add receipt line tax through generated single-line legacy receipts.
4. Build generic Tax Summary and Tax Audit Detail.
5. Add country-specific labels for AU, NZ, UK, CA, and US.
6. Keep US sales tax manual/configured by jurisdiction in the first version.
7. Add Xero tax code mappings after local reports are stable.

This gives HMB international tax reporting without turning the app into a full
jurisdictional tax engine.
