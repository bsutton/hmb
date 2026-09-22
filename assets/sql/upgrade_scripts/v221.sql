CREATE TABLE quickbooks_settings (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  client_id TEXT NOT NULL DEFAULT '',
  redirect_uri TEXT NOT NULL DEFAULT '',
  sandbox INTEGER NOT NULL DEFAULT 1,
  item_id TEXT NOT NULL DEFAULT '',
  taxable_code TEXT NOT NULL DEFAULT '',
  exempt_code TEXT NOT NULL DEFAULT '',
  us_tax_model INTEGER NOT NULL DEFAULT 0,
  transaction_tax_code TEXT NOT NULL DEFAULT ''
);
INSERT INTO quickbooks_settings (id) VALUES (1);
CREATE TABLE quickbooks_invoice_export (
  invoice_id INTEGER PRIMARY KEY REFERENCES invoice(id) ON DELETE RESTRICT,
  realm_id TEXT NOT NULL,
  sandbox INTEGER NOT NULL,
  request_id TEXT NOT NULL UNIQUE,
  payload_json TEXT NOT NULL,
  external_id TEXT,
  external_number TEXT,
  remote_total TEXT
);
