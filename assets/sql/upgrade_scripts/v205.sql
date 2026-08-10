ALTER TABLE receipt_job_allocation
ADD COLUMN invoice_line_id INTEGER;

CREATE INDEX IF NOT EXISTS receipt_job_allocation_invoice_line_idx
  ON receipt_job_allocation(invoice_line_id);
