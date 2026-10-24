-- Preserve legacy documents; new invoices explicitly opt into draft status.
ALTER TABLE invoice ADD COLUMN accounting_state TEXT NOT NULL DEFAULT 'issued';
ALTER TABLE invoice ADD COLUMN issued_date TEXT;
ALTER TABLE invoice ADD COLUMN voided_date TEXT;
ALTER TABLE invoice ADD COLUMN billing_request_id TEXT;
ALTER TABLE invoice ADD COLUMN billing_plan_hash TEXT;
UPDATE invoice SET issued_date = created_date;
CREATE UNIQUE INDEX invoice_billing_request ON invoice(billing_request_id)
  WHERE billing_request_id IS NOT NULL;

-- Historical void dates cannot be inferred from modified_date.
CREATE TRIGGER invoice_record_void AFTER UPDATE OF external_sync_status ON invoice
WHEN NEW.external_sync_status IN (2, 3)
  AND IFNULL(OLD.external_sync_status, 0) NOT IN (2, 3)
BEGIN
  UPDATE invoice SET voided_date = strftime('%Y-%m-%dT%H:%M:%f', 'now', 'localtime')
  WHERE id = NEW.id;
END;
CREATE TRIGGER invoice_record_issue AFTER UPDATE OF sent, paid, external_invoice_id ON invoice
WHEN NEW.accounting_state = 'draft'
  AND (NEW.sent = 1 OR NEW.paid = 1 OR NULLIF(NEW.external_invoice_id, '') IS NOT NULL)
BEGIN
  UPDATE invoice SET accounting_state = 'issued',
    issued_date = strftime('%Y-%m-%dT%H:%M:%f', 'now', 'localtime')
  WHERE id = NEW.id;
END;

CREATE TRIGGER invoice_issue_on_payment AFTER INSERT ON debtor_payment_allocation
BEGIN
 UPDATE invoice SET accounting_state = 'issued', issued_date = NEW.allocated_date
 WHERE id = NEW.invoice_id AND accounting_state = 'draft';
END;
CREATE TRIGGER invoice_issue_on_quickbooks AFTER UPDATE OF external_id ON quickbooks_invoice_export
WHEN NULLIF(NEW.external_id, '') IS NOT NULL
BEGIN
 UPDATE invoice SET accounting_state = 'issued',
 issued_date = strftime('%Y-%m-%dT%H:%M:%f', 'now', 'localtime')
 WHERE id = NEW.invoice_id AND accounting_state = 'draft';
END;

-- Active claims reserve whole sources. Releasing a draft retains claim history.
CREATE TABLE billing_allocation (
  id INTEGER PRIMARY KEY,
  invoice_id INTEGER NOT NULL,
  invoice_line_id INTEGER,
  source_type TEXT NOT NULL CHECK(source_type IN
    ('time', 'item', 'milestone', 'quote', 'task_scope', 'booking_fee')),
  source_id INTEGER NOT NULL,
  amount INTEGER NOT NULL,
  created_date TEXT NOT NULL,
  released_date TEXT
);
CREATE UNIQUE INDEX billing_active_source
  ON billing_allocation(source_type, source_id) WHERE released_date IS NULL;
CREATE INDEX billing_invoice ON billing_allocation(invoice_id);
CREATE TABLE task_fixed_agreement (
  id INTEGER PRIMARY KEY,
  task_id INTEGER NOT NULL UNIQUE REFERENCES task(id),
  job_id INTEGER NOT NULL REFERENCES job(id),
  amount INTEGER NOT NULL CHECK(amount > 0),
  agreed_date TEXT NOT NULL,
  agreement_note TEXT NOT NULL,
  created_date TEXT NOT NULL,
  modified_date TEXT NOT NULL
);
CREATE TABLE billing_review (
  id INTEGER PRIMARY KEY,
  job_id INTEGER,
  invoice_id INTEGER,
  reason TEXT NOT NULL,
  resolved_date TEXT
);

-- Backfill only direct, unambiguous source links, without changing amounts.
INSERT INTO billing_allocation
  (invoice_id, invoice_line_id, source_type, source_id, amount, created_date)
SELECT l.invoice_id, l.id, 'time', t.id, 0, i.created_date
FROM time_entry t JOIN invoice_line l ON l.id = t.invoice_line_id
JOIN invoice i ON i.id = l.invoice_id
WHERE t.billed = 1;
INSERT INTO billing_allocation
  (invoice_id, invoice_line_id, source_type, source_id, amount, created_date)
SELECT l.invoice_id, l.id, 'item', t.id, 0, i.created_date
FROM task_item t JOIN invoice_line l ON l.id = t.invoice_line_id
JOIN invoice i ON i.id = l.invoice_id
WHERE t.billed = 1;
INSERT INTO billing_allocation
  (invoice_id, source_type, source_id, amount, created_date)
SELECT i.id, 'milestone', m.id, m.payment_amount, i.created_date
FROM milestone m JOIN invoice i ON i.id = m.invoice_id;
INSERT INTO billing_review (job_id, invoice_id, reason)
SELECT i.job_id, i.id, 'Legacy milestone has no verified invoice-line mapping'
FROM invoice i JOIN milestone m ON m.invoice_id = i.id;
INSERT INTO billing_review (job_id, invoice_id, reason)
SELECT job_id, id, 'Historical void date is unknown'
FROM invoice WHERE external_sync_status IN (2, 3);
INSERT INTO billing_allocation
 (invoice_id, invoice_line_id, source_type, source_id, amount, created_date)
SELECT i.id, l.id, 'booking_fee', i.job_id, l.line_total, i.created_date
FROM invoice_line l JOIN invoice i ON i.id = l.invoice_id
WHERE l.from_booking_fee = 1 AND (
 SELECT COUNT(*) FROM invoice_line other JOIN invoice oi ON oi.id = other.invoice_id
 WHERE oi.job_id = i.job_id AND other.from_booking_fee = 1) = 1;
INSERT INTO billing_review (job_id, reason)
SELECT i.job_id, 'Multiple legacy booking-fee lines require reconciliation'
FROM invoice_line l JOIN invoice i ON i.id = l.invoice_id
WHERE l.from_booking_fee = 1 GROUP BY i.job_id HAVING COUNT(*) > 1;
INSERT INTO billing_review (job_id, reason)
SELECT job_id, 'Approved quotes contain overlapping task scope'
FROM quote q JOIN quote_line_group g ON g.quote_id = q.id
WHERE q.state IN ('approved', 'invoiced') AND g.task_id IS NOT NULL
  AND g.line_approval_status != 'rejected'
GROUP BY job_id, g.task_id HAVING COUNT(DISTINCT q.id) > 1;

-- Freeze the current effective assignment before introducing default-for-new
-- task behaviour. This never changes an existing task's price or source links.
UPDATE task SET billing_type = (SELECT billing_type FROM job WHERE id = task.job_id)
WHERE billing_type IS NULL;

-- A final quote payment and a milestone schedule are alternative slices.
CREATE TRIGGER billing_quote_claim BEFORE INSERT ON billing_allocation
WHEN NEW.released_date IS NULL AND (
 (NEW.source_type = 'quote' AND EXISTS (
  SELECT 1 FROM billing_allocation a JOIN milestone m ON m.id = a.source_id
  WHERE a.source_type = 'milestone' AND m.quote_id = NEW.source_id
    AND a.released_date IS NULL))
 OR
 (NEW.source_type = 'milestone' AND EXISTS (
  SELECT 1 FROM billing_allocation a JOIN milestone m ON m.id = NEW.source_id
  WHERE a.source_type = 'quote' AND a.source_id = m.quote_id
    AND a.released_date IS NULL)))
BEGIN
 SELECT RAISE(ABORT, 'Fixed scope already has a billing allocation');
END;

CREATE TRIGGER milestone_protect_reserved BEFORE UPDATE OF
 payment_amount, quote_id, voided ON milestone
WHEN OLD.invoice_id IS NOT NULL AND
 (NEW.payment_amount != OLD.payment_amount OR NEW.quote_id != OLD.quote_id
  OR NEW.voided != OLD.voided)
BEGIN
 SELECT RAISE(ABORT, 'Invoiced milestone cannot be changed');
END;
CREATE TRIGGER milestone_protect_delete BEFORE DELETE ON milestone
WHEN OLD.invoice_id IS NOT NULL OR EXISTS (
 SELECT 1 FROM billing_allocation a WHERE a.source_type = 'milestone'
 AND a.source_id = OLD.id AND a.released_date IS NULL)
BEGIN
 SELECT RAISE(ABORT, 'Reserved milestone cannot be deleted');
END;

-- Flag unprovable legacy ownership instead of inventing a backfill.
INSERT INTO billing_review (job_id, reason)
SELECT t.job_id, 'Billed time has a missing invoice-line link'
FROM time_entry e JOIN task t ON t.id = e.task_id
LEFT JOIN invoice_line l ON l.id = e.invoice_line_id
WHERE e.billed = 1 AND l.id IS NULL;
INSERT INTO billing_review (job_id, reason)
SELECT t.job_id, 'Billed material has a missing invoice-line link'
FROM task_item e JOIN task t ON t.id = e.task_id
LEFT JOIN invoice_line l ON l.id = e.invoice_line_id
WHERE e.billed = 1 AND l.id IS NULL;
INSERT INTO billing_review (job_id, reason)
SELECT q.job_id, 'Invoiced quote has no verified fixed-scope allocation'
FROM quote q WHERE q.state = 'invoiced' AND NOT EXISTS
 (SELECT 1 FROM milestone m WHERE m.quote_id = q.id AND m.invoice_id IS NOT NULL);

CREATE TRIGGER quote_protect_price BEFORE UPDATE OF total_amount, state ON quote
WHEN EXISTS (SELECT 1 FROM billing_allocation a
 LEFT JOIN milestone m ON a.source_type = 'milestone' AND m.id = a.source_id
 WHERE a.released_date IS NULL AND
 ((a.source_type = 'quote' AND a.source_id = OLD.id) OR m.quote_id = OLD.id)) AND (NEW.total_amount != OLD.total_amount OR
 (NEW.state != OLD.state AND NOT (OLD.state = 'approved' AND NEW.state = 'invoiced')))
BEGIN
 SELECT RAISE(ABORT, 'Invoiced quote requires a separate variation');
END;

CREATE TRIGGER quote_line_protect_update BEFORE UPDATE ON quote_line
WHEN EXISTS (SELECT 1 FROM billing_allocation a
 LEFT JOIN milestone m ON a.source_type = 'milestone' AND m.id = a.source_id
 WHERE a.released_date IS NULL AND
 ((a.source_type = 'quote' AND a.source_id = OLD.quote_id) OR m.quote_id = OLD.quote_id))
BEGIN
 SELECT RAISE(ABORT, 'Invoiced quote scope requires a separate variation');
END;

CREATE TRIGGER quote_line_protect_insert BEFORE INSERT ON quote_line
WHEN EXISTS (SELECT 1 FROM billing_allocation a
 LEFT JOIN milestone m ON a.source_type = 'milestone' AND m.id = a.source_id
 WHERE a.released_date IS NULL AND
 ((a.source_type = 'quote' AND a.source_id = NEW.quote_id) OR m.quote_id = NEW.quote_id))
BEGIN
 SELECT RAISE(ABORT, 'Invoiced quote scope requires a separate variation');
END;

CREATE TRIGGER quote_line_group_protect_insert BEFORE INSERT ON quote_line_group
WHEN EXISTS (SELECT 1 FROM billing_allocation a
 LEFT JOIN milestone m ON a.source_type = 'milestone' AND m.id = a.source_id
 WHERE a.released_date IS NULL AND
 ((a.source_type = 'quote' AND a.source_id = NEW.quote_id) OR m.quote_id = NEW.quote_id))
BEGIN
 SELECT RAISE(ABORT, 'Invoiced quote scope requires a separate variation');
END;

CREATE TRIGGER quote_line_protect_delete BEFORE DELETE ON quote_line
WHEN EXISTS (SELECT 1 FROM billing_allocation a
 LEFT JOIN milestone m ON a.source_type = 'milestone' AND m.id = a.source_id
 WHERE a.released_date IS NULL AND
 ((a.source_type = 'quote' AND a.source_id = OLD.quote_id) OR m.quote_id = OLD.quote_id))
BEGIN
 SELECT RAISE(ABORT, 'Invoiced quote scope requires a separate variation');
END;

CREATE TRIGGER quote_line_group_protect_update BEFORE UPDATE ON quote_line_group
WHEN EXISTS (SELECT 1 FROM billing_allocation a
 LEFT JOIN milestone m ON a.source_type = 'milestone' AND m.id = a.source_id
 WHERE a.released_date IS NULL AND
 ((a.source_type = 'quote' AND a.source_id = OLD.quote_id) OR m.quote_id = OLD.quote_id))
BEGIN
 SELECT RAISE(ABORT, 'Invoiced quote scope requires a separate variation');
END;

CREATE TRIGGER quote_line_group_protect_delete BEFORE DELETE ON quote_line_group
WHEN EXISTS (SELECT 1 FROM billing_allocation a
 LEFT JOIN milestone m ON a.source_type = 'milestone' AND m.id = a.source_id
 WHERE a.released_date IS NULL AND
 ((a.source_type = 'quote' AND a.source_id = OLD.quote_id) OR m.quote_id = OLD.quote_id))
BEGIN
 SELECT RAISE(ABORT, 'Invoiced quote scope requires a separate variation');
END;
