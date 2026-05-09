ALTER TABLE invoice_line
ADD COLUMN tax_amount INTEGER NOT NULL DEFAULT 0;

ALTER TABLE invoice_line
ADD COLUMN tax_type TEXT;

ALTER TABLE credit_note_line
ADD COLUMN tax_amount INTEGER NOT NULL DEFAULT 0;

UPDATE receipt_job_allocation
SET
  amount = (
    SELECT receipt.total_excluding_tax
    FROM receipt
    WHERE receipt.id = receipt_job_allocation.receipt_id
  ),
  modified_date = datetime('now')
WHERE receipt_id IN (
  SELECT receipt_id
  FROM receipt_job_allocation
  GROUP BY receipt_id
  HAVING COUNT(*) = 1
)
AND amount != (
  SELECT receipt.total_excluding_tax
  FROM receipt
  WHERE receipt.id = receipt_job_allocation.receipt_id
);
