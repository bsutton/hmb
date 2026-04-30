ALTER TABLE invoice
ADD COLUMN external_sync_status INTEGER NOT NULL DEFAULT 0;

ALTER TABLE invoice
ADD COLUMN payment_source INTEGER NOT NULL DEFAULT 0;

UPDATE invoice
SET external_sync_status = CASE
  WHEN UPPER(IFNULL(external_status, '')) = 'DELETED' THEN 2
  WHEN UPPER(IFNULL(external_status, '')) = 'VOIDED' THEN 3
  WHEN IFNULL(external_invoice_id, '') != '' THEN 1
  ELSE 0
END;

UPDATE invoice
SET payment_source = CASE
  WHEN IFNULL(external_invoice_id, '') != '' THEN 1
  ELSE 2
END;

CREATE INDEX invoice_external_sync_status_idx
ON invoice(external_sync_status, payment_source);
