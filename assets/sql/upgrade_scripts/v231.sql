-- A void can restore approval without releasing any billing reservation.
CREATE VIEW IF NOT EXISTS invoice_void_quote_link AS
SELECT quote_id, invoice_id FROM cancellation_quote_invoice
UNION ALL
SELECT a.source_id, a.invoice_id FROM billing_allocation a
WHERE a.source_type = 'quote' AND a.released_date IS NOT NULL
UNION ALL
SELECT m.quote_id, a.invoice_id FROM billing_allocation a
JOIN milestone m ON m.id = a.source_id
WHERE a.source_type = 'milestone' AND a.released_date IS NOT NULL;

CREATE VIEW IF NOT EXISTS invoice_void_reopenable_quote AS
SELECT q.id FROM quote q
JOIN job j ON j.id = q.job_id AND j.status_id != 'Rejected'
WHERE q.state = 'invoiced'
AND EXISTS (
  SELECT 1 FROM cancellation_quote_invoice l WHERE l.quote_id = q.id
)
AND NOT EXISTS (
  SELECT 1 FROM invoice_void_quote_link l
  WHERE l.quote_id = q.id AND NOT EXISTS (
    SELECT 1 FROM cancellation_void_invoice i
    WHERE i.id = l.invoice_id AND i.job_id = q.job_id
  )
);

DROP TRIGGER IF EXISTS quote_protect_price;
CREATE TRIGGER quote_protect_price BEFORE UPDATE OF total_amount, state ON quote
WHEN (
  OLD.state = 'invoiced' AND NEW.state = 'approved' AND NOT EXISTS (
    SELECT 1 FROM invoice_void_reopenable_quote q WHERE q.id = OLD.id
  )
) OR (
 EXISTS (SELECT 1 FROM billing_allocation a
 LEFT JOIN milestone m ON a.source_type = 'milestone' AND m.id = a.source_id
 WHERE a.released_date IS NULL AND
 ((a.source_type = 'quote' AND a.source_id = OLD.id) OR m.quote_id = OLD.id))
 AND (NEW.total_amount != OLD.total_amount OR (NEW.state != OLD.state
  AND NOT (OLD.state = 'approved' AND NEW.state = 'invoiced')
  AND NOT (OLD.state = 'invoiced' AND NEW.state = 'approved')
  AND NOT (NEW.state = 'rejected' AND EXISTS (
   SELECT 1 FROM cancellation_rejectable_quote q WHERE q.id = OLD.id
  ))))
)
BEGIN
 SELECT RAISE(ABORT, 'Invoiced quote requires a separate variation');
END;

CREATE TRIGGER IF NOT EXISTS quote_record_reopen_after_void
AFTER UPDATE OF state ON quote
WHEN OLD.state = 'invoiced' AND NEW.state = 'approved'
BEGIN
 INSERT INTO lifecycle_transition
  (aggregate_type, aggregate_id, job_id, event, from_state, to_state,
   source, correlation_id, occurred_at)
 VALUES
  ('quote', NEW.id, NEW.job_id, 'RestoreApprovalAfterInvoiceVoid',
   OLD.state, NEW.state, 'invoice.void', lower(hex(randomblob(16))),
   NEW.modified_date);
END;

-- Reconcile provably safe legacy quotes; do not change invoices or jobs.
UPDATE quote SET state = 'approved',
  modified_date = strftime('%Y-%m-%dT%H:%M:%f', 'now', 'localtime')
WHERE id IN (SELECT id FROM invoice_void_reopenable_quote);
