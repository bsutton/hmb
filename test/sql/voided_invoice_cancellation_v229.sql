CREATE TABLE job (id INTEGER PRIMARY KEY, status_id TEXT);
CREATE TABLE invoice (
  id INTEGER PRIMARY KEY, job_id INTEGER, external_sync_status INTEGER,
  paid INTEGER, paid_date TEXT
);
CREATE TABLE quote (
  id INTEGER PRIMARY KEY, job_id INTEGER, state TEXT, total_amount INTEGER
);
CREATE TABLE milestone (id INTEGER PRIMARY KEY, quote_id INTEGER, invoice_id INTEGER);
CREATE TABLE billing_allocation (
  invoice_id INTEGER, source_type TEXT, source_id INTEGER, released_date TEXT
);
CREATE TABLE debtor_payment_allocation (invoice_id INTEGER);
CREATE TABLE credit_allocation (invoice_id INTEGER);
CREATE TABLE debtor_adjustment (invoice_id INTEGER);
CREATE TABLE quickbooks_invoice_export (invoice_id INTEGER);

CREATE TRIGGER quote_protect_price BEFORE UPDATE OF total_amount, state ON quote
WHEN OLD.state = 'invoiced'
BEGIN
  SELECT RAISE(ABORT, 'Invoiced quote requires a separate variation');
END;

INSERT INTO job VALUES (1, 'awaitingPayment');
INSERT INTO invoice VALUES (8, 1, 3, 0, NULL), (9, 1, 0, 0, NULL);
INSERT INTO quote VALUES
  (178, 1, 'invoiced', 10000), (179, 1, 'invoiced', 10000),
  (180, 1, 'invoiced', 10000);
INSERT INTO milestone VALUES (20, 178, 8), (21, 179, 9);
INSERT INTO billing_allocation VALUES
  (8, 'milestone', 20, NULL), (9, 'milestone', 21, NULL);
