ALTER TABLE invoice
ADD COLUMN paid INTEGER NOT NULL DEFAULT 0;

ALTER TABLE invoice
ADD COLUMN paid_date TEXT;

CREATE INDEX invoice_paid_sync_idx
ON invoice(paid, sent, external_invoice_id);
