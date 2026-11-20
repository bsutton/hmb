-- A cancelled job keeps its invoices and billing reservations. Legacy links
-- now use these same checks without changing any stored job or invoice state.
CREATE VIEW IF NOT EXISTS cancellation_void_invoice AS
SELECT i.id, i.job_id FROM invoice i
WHERE i.external_sync_status = 3 AND i.paid = 0 AND i.paid_date IS NULL
  AND NOT EXISTS (SELECT 1 FROM debtor_payment_allocation p WHERE p.invoice_id = i.id)
  AND NOT EXISTS (SELECT 1 FROM credit_allocation c WHERE c.invoice_id = i.id)
  AND NOT EXISTS (SELECT 1 FROM debtor_adjustment a WHERE a.invoice_id = i.id)
  AND NOT EXISTS (SELECT 1 FROM quickbooks_invoice_export e WHERE e.invoice_id = i.id);

CREATE VIEW IF NOT EXISTS cancellation_quote_invoice AS
SELECT m.quote_id, m.invoice_id
FROM milestone m WHERE m.invoice_id IS NOT NULL
UNION ALL
SELECT a.source_id, a.invoice_id FROM billing_allocation a
WHERE a.source_type = 'quote' AND a.released_date IS NULL
UNION ALL
SELECT m.quote_id, a.invoice_id FROM billing_allocation a
JOIN milestone m ON m.id = a.source_id
WHERE a.source_type = 'milestone' AND a.released_date IS NULL;

CREATE VIEW IF NOT EXISTS cancellation_rejectable_quote AS
SELECT q.id FROM quote q
WHERE (q.state != 'invoiced' OR EXISTS (
  SELECT 1 FROM cancellation_quote_invoice l WHERE l.quote_id = q.id
))
AND NOT EXISTS (
  SELECT 1 FROM cancellation_quote_invoice l
  WHERE l.quote_id = q.id AND NOT EXISTS (
    SELECT 1 FROM cancellation_void_invoice i
    WHERE i.id = l.invoice_id AND i.job_id = q.job_id
  )
);

DROP TRIGGER IF EXISTS quote_protect_price;
CREATE TRIGGER quote_protect_price BEFORE UPDATE OF total_amount, state ON quote
WHEN EXISTS (SELECT 1 FROM billing_allocation a
 LEFT JOIN milestone m ON a.source_type = 'milestone' AND m.id = a.source_id
 WHERE a.released_date IS NULL AND
 ((a.source_type = 'quote' AND a.source_id = OLD.id) OR m.quote_id = OLD.id))
 AND (NEW.total_amount != OLD.total_amount OR (NEW.state != OLD.state
  AND NOT (OLD.state = 'approved' AND NEW.state = 'invoiced')
  AND NOT (NEW.state = 'rejected' AND EXISTS (
   SELECT 1 FROM cancellation_rejectable_quote q WHERE q.id = OLD.id
  ))))
BEGIN
 SELECT RAISE(ABORT, 'Invoiced quote requires a separate variation');
END;
