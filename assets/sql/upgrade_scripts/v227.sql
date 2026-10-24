-- Xero customer credits are separate from payments attached to invoices.
CREATE TABLE xero_customer_credit (
  tenant_id TEXT NOT NULL,
  external_id TEXT NOT NULL,
  customer_id INTEGER NOT NULL REFERENCES customer(id),
  credit_date TEXT NOT NULL,
  amount INTEGER NOT NULL,
  remaining_credit INTEGER NOT NULL,
  reference TEXT,
  PRIMARY KEY (tenant_id, external_id)
);
CREATE TABLE xero_customer_credit_event (
  tenant_id TEXT NOT NULL,
  credit_id TEXT NOT NULL,
  event_id TEXT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('refund', 'allocation')),
  event_date TEXT NOT NULL,
  amount INTEGER NOT NULL,
  invoice_external_id TEXT,
  PRIMARY KEY (tenant_id, credit_id, event_id)
);
