-- Released allocations still identify an invoice that exists. Released
-- allocations from deleted drafts are retained for audit without an invoice.
-- Match the owner and creation date because deleted source IDs can be reused.
DROP VIEW IF EXISTS invoice_void_quote_link;
CREATE VIEW invoice_void_quote_link AS
SELECT quote_id, invoice_id FROM cancellation_quote_invoice
UNION ALL
SELECT a.source_id, a.invoice_id FROM billing_allocation a
JOIN quote q ON q.id = a.source_id
JOIN invoice i ON i.id = a.invoice_id
  AND i.job_id = q.job_id
WHERE a.source_type = 'quote' AND a.released_date IS NOT NULL
  AND julianday(a.created_date) >= julianday(q.created_date)
UNION ALL
SELECT m.quote_id, a.invoice_id FROM billing_allocation a
JOIN milestone m ON m.id = a.source_id
JOIN quote q ON q.id = m.quote_id
JOIN invoice i ON i.id = a.invoice_id
  AND i.job_id = q.job_id
WHERE a.source_type = 'milestone' AND a.released_date IS NOT NULL
  AND julianday(a.created_date) >= julianday(m.created_date)
  AND julianday(a.created_date) >= julianday(q.created_date);

DROP VIEW IF EXISTS cancellation_rejectable_quote;
CREATE VIEW cancellation_rejectable_quote AS
SELECT q.id FROM quote q
WHERE (q.state != 'invoiced' OR EXISTS (
  SELECT 1 FROM invoice_void_quote_link l WHERE l.quote_id = q.id
))
AND NOT EXISTS (
  SELECT 1 FROM invoice_void_quote_link l
  WHERE l.quote_id = q.id AND NOT EXISTS (
    SELECT 1 FROM cancellation_void_invoice i
    WHERE i.id = l.invoice_id AND i.job_id = q.job_id
  )
);

-- Retry the v231 repair for quotes whose only blocker was a deleted draft.
UPDATE quote SET state = 'approved',
  modified_date = strftime('%Y-%m-%dT%H:%M:%f', 'now', 'localtime')
WHERE id IN (SELECT id FROM invoice_void_reopenable_quote);
