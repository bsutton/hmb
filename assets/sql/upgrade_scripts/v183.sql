CREATE TABLE IF NOT EXISTS debtor_transaction (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  debtor_customer_id INTEGER,
  debtor_contact_id INTEGER,
  job_id INTEGER,
  transaction_type INTEGER NOT NULL,
  source_table TEXT NOT NULL,
  source_id INTEGER NOT NULL,
  transaction_date TEXT NOT NULL,
  amount INTEGER NOT NULL,
  tax_amount INTEGER NOT NULL DEFAULT 0,
  description TEXT,
  created_date TEXT NOT NULL DEFAULT (datetime('now')),
  modified_date TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY(debtor_customer_id) REFERENCES customer(id),
  FOREIGN KEY(debtor_contact_id) REFERENCES contact(id),
  FOREIGN KEY(job_id) REFERENCES job(id),
  UNIQUE(transaction_type, source_table, source_id)
);

CREATE INDEX IF NOT EXISTS debtor_transaction_customer_idx
  ON debtor_transaction(debtor_customer_id, transaction_date);

CREATE INDEX IF NOT EXISTS debtor_transaction_job_idx
  ON debtor_transaction(job_id, transaction_date);

CREATE TABLE IF NOT EXISTS debtor_payment (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  customer_id INTEGER,
  contact_id INTEGER,
  payment_date TEXT NOT NULL,
  amount INTEGER NOT NULL,
  payment_method TEXT,
  reference TEXT,
  notes TEXT,
  external_payment_id TEXT,
  external_provider TEXT,
  created_date TEXT NOT NULL DEFAULT (datetime('now')),
  modified_date TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY(customer_id) REFERENCES customer(id),
  FOREIGN KEY(contact_id) REFERENCES contact(id)
);

CREATE INDEX IF NOT EXISTS debtor_payment_customer_idx
  ON debtor_payment(customer_id, payment_date);

CREATE TABLE IF NOT EXISTS debtor_payment_allocation (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  payment_id INTEGER NOT NULL,
  invoice_id INTEGER NOT NULL,
  amount INTEGER NOT NULL,
  allocated_date TEXT NOT NULL,
  external_allocation_id TEXT,
  created_date TEXT NOT NULL DEFAULT (datetime('now')),
  modified_date TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY(payment_id) REFERENCES debtor_payment(id),
  FOREIGN KEY(invoice_id) REFERENCES invoice(id)
);

CREATE INDEX IF NOT EXISTS debtor_payment_allocation_payment_idx
  ON debtor_payment_allocation(payment_id);

CREATE INDEX IF NOT EXISTS debtor_payment_allocation_invoice_idx
  ON debtor_payment_allocation(invoice_id);

CREATE TABLE IF NOT EXISTS credit_note (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  customer_id INTEGER,
  contact_id INTEGER,
  job_id INTEGER,
  related_invoice_id INTEGER,
  credit_note_num TEXT,
  external_credit_note_id TEXT,
  credit_date TEXT NOT NULL,
  total_amount INTEGER NOT NULL,
  status INTEGER NOT NULL DEFAULT 0,
  reason TEXT,
  created_date TEXT NOT NULL DEFAULT (datetime('now')),
  modified_date TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY(customer_id) REFERENCES customer(id),
  FOREIGN KEY(contact_id) REFERENCES contact(id),
  FOREIGN KEY(job_id) REFERENCES job(id),
  FOREIGN KEY(related_invoice_id) REFERENCES invoice(id)
);

CREATE INDEX IF NOT EXISTS credit_note_customer_idx
  ON credit_note(customer_id, credit_date);

CREATE INDEX IF NOT EXISTS credit_note_invoice_idx
  ON credit_note(related_invoice_id);

CREATE TABLE IF NOT EXISTS credit_note_line (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  credit_note_id INTEGER NOT NULL,
  description TEXT NOT NULL,
  quantity INTEGER NOT NULL DEFAULT 100,
  unit_price INTEGER NOT NULL DEFAULT 0,
  line_total INTEGER NOT NULL DEFAULT 0,
  income_account_code TEXT,
  tax_type TEXT,
  created_date TEXT NOT NULL DEFAULT (datetime('now')),
  modified_date TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY(credit_note_id) REFERENCES credit_note(id)
);

CREATE INDEX IF NOT EXISTS credit_note_line_credit_note_idx
  ON credit_note_line(credit_note_id);

CREATE TABLE IF NOT EXISTS credit_allocation (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  credit_note_id INTEGER NOT NULL,
  invoice_id INTEGER NOT NULL,
  amount INTEGER NOT NULL,
  allocated_date TEXT NOT NULL,
  external_allocation_id TEXT,
  created_date TEXT NOT NULL DEFAULT (datetime('now')),
  modified_date TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY(credit_note_id) REFERENCES credit_note(id),
  FOREIGN KEY(invoice_id) REFERENCES invoice(id)
);

CREATE INDEX IF NOT EXISTS credit_allocation_credit_note_idx
  ON credit_allocation(credit_note_id);

CREATE INDEX IF NOT EXISTS credit_allocation_invoice_idx
  ON credit_allocation(invoice_id);

CREATE TABLE IF NOT EXISTS debtor_adjustment (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  customer_id INTEGER,
  contact_id INTEGER,
  job_id INTEGER,
  invoice_id INTEGER,
  adjustment_type INTEGER NOT NULL,
  adjustment_date TEXT NOT NULL,
  amount INTEGER NOT NULL,
  reason TEXT NOT NULL,
  notes TEXT,
  created_date TEXT NOT NULL DEFAULT (datetime('now')),
  modified_date TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY(customer_id) REFERENCES customer(id),
  FOREIGN KEY(contact_id) REFERENCES contact(id),
  FOREIGN KEY(job_id) REFERENCES job(id),
  FOREIGN KEY(invoice_id) REFERENCES invoice(id)
);

CREATE INDEX IF NOT EXISTS debtor_adjustment_invoice_idx
  ON debtor_adjustment(invoice_id, adjustment_date);

CREATE TABLE IF NOT EXISTS external_accounting_link (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  provider TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  local_id INTEGER NOT NULL,
  external_id TEXT,
  external_number TEXT,
  sync_status INTEGER NOT NULL DEFAULT 0,
  last_synced_at TEXT,
  remote_updated_at TEXT,
  last_error TEXT,
  content_hash TEXT,
  created_date TEXT NOT NULL DEFAULT (datetime('now')),
  modified_date TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(provider, entity_type, local_id)
);

CREATE INDEX IF NOT EXISTS external_accounting_link_external_idx
  ON external_accounting_link(provider, entity_type, external_id);

CREATE TABLE IF NOT EXISTS receipt_job_allocation (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  receipt_id INTEGER NOT NULL,
  job_id INTEGER NOT NULL,
  amount INTEGER NOT NULL,
  created_date TEXT NOT NULL DEFAULT (datetime('now')),
  modified_date TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY(receipt_id) REFERENCES receipt(id),
  FOREIGN KEY(job_id) REFERENCES job(id)
);

CREATE INDEX IF NOT EXISTS receipt_job_allocation_receipt_idx
  ON receipt_job_allocation(receipt_id);

CREATE INDEX IF NOT EXISTS receipt_job_allocation_job_idx
  ON receipt_job_allocation(job_id);

INSERT OR IGNORE INTO debtor_transaction (
  debtor_customer_id,
  debtor_contact_id,
  job_id,
  transaction_type,
  source_table,
  source_id,
  transaction_date,
  amount,
  tax_amount,
  description,
  created_date,
  modified_date
)
SELECT
  job.customer_id,
  invoice.billing_contact_id,
  invoice.job_id,
  0,
  'invoice',
  invoice.id,
  invoice.created_date,
  invoice.total_amount,
  0,
  'Invoice #' || invoice.id,
  invoice.created_date,
  invoice.modified_date
FROM invoice
JOIN job ON job.id = invoice.job_id;

INSERT OR IGNORE INTO external_accounting_link (
  provider,
  entity_type,
  local_id,
  external_id,
  external_number,
  sync_status,
  last_synced_at,
  created_date,
  modified_date
)
SELECT
  'xero',
  'invoice',
  id,
  external_invoice_id,
  invoice_num,
  external_sync_status,
  modified_date,
  created_date,
  modified_date
FROM invoice
WHERE IFNULL(external_invoice_id, '') != ''
   OR IFNULL(invoice_num, '') != '';

INSERT INTO receipt_job_allocation (
  receipt_id,
  job_id,
  amount,
  created_date,
  modified_date
)
SELECT
  id,
  job_id,
  total_excluding_tax,
  created_date,
  modified_date
FROM receipt
WHERE NOT EXISTS (
  SELECT 1
  FROM receipt_job_allocation
  WHERE receipt_job_allocation.receipt_id = receipt.id
);
