CREATE TABLE IF NOT EXISTS tax_scheme (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  country_code TEXT NOT NULL,
  code TEXT NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  tax_label TEXT NOT NULL,
  supports_input_credits INTEGER NOT NULL DEFAULT 1,
  supports_jurisdiction_reporting INTEGER NOT NULL DEFAULT 0,
  created_date TEXT NOT NULL DEFAULT (datetime('now')),
  modified_date TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS tax_code (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tax_scheme_id INTEGER NOT NULL,
  code TEXT NOT NULL,
  display_name TEXT NOT NULL,
  rate_basis_points INTEGER NOT NULL DEFAULT 0,
  tax_treatment TEXT NOT NULL DEFAULT 'taxable',
  jurisdiction_name TEXT,
  effective_from TEXT NOT NULL DEFAULT '1900-01-01',
  effective_to TEXT,
  external_provider TEXT,
  external_tax_code TEXT,
  is_default_sales INTEGER NOT NULL DEFAULT 0,
  is_default_purchase INTEGER NOT NULL DEFAULT 0,
  created_date TEXT NOT NULL DEFAULT (datetime('now')),
  modified_date TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY(tax_scheme_id) REFERENCES tax_scheme(id),
  UNIQUE(tax_scheme_id, code, effective_from)
);

CREATE INDEX IF NOT EXISTS tax_code_scheme_idx
  ON tax_code(tax_scheme_id, code);

CREATE INDEX IF NOT EXISTS tax_code_effective_idx
  ON tax_code(tax_scheme_id, effective_from, effective_to);

ALTER TABLE invoice_line
ADD COLUMN tax_code_id INTEGER;

CREATE INDEX IF NOT EXISTS invoice_line_tax_code_idx
  ON invoice_line(tax_code_id);

ALTER TABLE credit_note_line
ADD COLUMN tax_code_id INTEGER;

CREATE INDEX IF NOT EXISTS credit_note_line_tax_code_idx
  ON credit_note_line(tax_code_id);

ALTER TABLE receipt_line_item
ADD COLUMN tax_code_id INTEGER;

CREATE INDEX IF NOT EXISTS receipt_line_item_tax_code_idx
  ON receipt_line_item(tax_code_id);

INSERT OR IGNORE INTO tax_scheme (
  country_code,
  code,
  display_name,
  tax_label,
  supports_input_credits,
  supports_jurisdiction_reporting
) VALUES
  ('AU', 'au_gst', 'Australia GST', 'GST', 1, 0),
  ('NZ', 'nz_gst', 'New Zealand GST', 'GST', 1, 0),
  ('GB', 'uk_vat', 'United Kingdom VAT', 'VAT', 1, 0),
  ('CA', 'ca_gst_hst', 'Canada GST/HST', 'GST/HST', 1, 1),
  ('US', 'us_sales_tax', 'United States sales tax', 'Sales tax', 0, 1),
  ('', 'custom', 'Custom tax scheme', 'Tax', 1, 1);

INSERT OR IGNORE INTO tax_code (
  tax_scheme_id,
  code,
  display_name,
  rate_basis_points,
  tax_treatment,
  jurisdiction_name,
  is_default_sales,
  is_default_purchase
)
SELECT
  tax_scheme.id,
  seed.code,
  seed.display_name,
  seed.rate_basis_points,
  seed.tax_treatment,
  seed.jurisdiction_name,
  seed.is_default_sales,
  seed.is_default_purchase
FROM tax_scheme
JOIN (
  SELECT
    'au_gst' AS scheme_code,
    'gst_10' AS code,
    'GST 10%' AS display_name,
    1000 AS rate_basis_points,
    'taxable' AS tax_treatment,
    NULL AS jurisdiction_name,
    1 AS is_default_sales,
    1 AS is_default_purchase
  UNION ALL SELECT 'au_gst', 'gst_free', 'GST-free', 0, 'zero_rated', NULL, 0, 0
  UNION ALL SELECT 'au_gst', 'out_of_scope', 'Out of scope', 0, 'out_of_scope', NULL, 0, 0
  UNION ALL SELECT 'nz_gst', 'gst_15', 'GST 15%', 1500, 'taxable', NULL, 1, 1
  UNION ALL SELECT 'nz_gst', 'zero_rated', 'Zero-rated', 0, 'zero_rated', NULL, 0, 0
  UNION ALL SELECT 'uk_vat', 'vat_20', 'VAT 20%', 2000, 'taxable', NULL, 1, 1
  UNION ALL SELECT 'uk_vat', 'vat_zero', 'VAT zero-rated', 0, 'zero_rated', NULL, 0, 0
  UNION ALL SELECT 'uk_vat', 'vat_exempt', 'VAT exempt', 0, 'exempt', NULL, 0, 0
  UNION ALL SELECT 'ca_gst_hst', 'gst_5', 'GST 5%', 500, 'taxable', 'Federal', 1, 1
  UNION ALL SELECT 'ca_gst_hst', 'zero_rated', 'Zero-rated', 0, 'zero_rated', NULL, 0, 0
  UNION ALL SELECT 'us_sales_tax', 'manual_sales_tax', 'Manual sales tax', 0, 'manual', NULL, 1, 0
  UNION ALL SELECT 'us_sales_tax', 'non_taxable', 'Non-taxable', 0, 'out_of_scope', NULL, 0, 1
  UNION ALL SELECT 'custom', 'taxable', 'Taxable', 0, 'manual', NULL, 1, 1
  UNION ALL SELECT 'custom', 'out_of_scope', 'Out of scope', 0, 'out_of_scope', NULL, 0, 0
) seed ON seed.scheme_code = tax_scheme.code;
