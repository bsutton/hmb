CREATE TABLE job (id INTEGER PRIMARY KEY, billing_type TEXT);
INSERT INTO job VALUES (1, 'fixedPrice');
CREATE TABLE task (id INTEGER PRIMARY KEY, job_id INTEGER, billing_type TEXT);
INSERT INTO task VALUES (1, 1, NULL);
CREATE TABLE invoice (
 id INTEGER PRIMARY KEY, job_id INTEGER, total_amount INTEGER,
 created_date TEXT, modified_date TEXT, due_date TEXT,
 external_sync_status INTEGER, sent INTEGER, paid INTEGER, external_invoice_id TEXT
);
INSERT INTO invoice VALUES
 (1,1,30000,'2026-06-01T09:00:00','2026-06-01T09:00:00',
 '2026-06-15',0,1,0,NULL),
 (2,1,10000,'2026-05-01T09:00:00','2026-05-01T09:00:00',
 '2026-05-15',3,1,0,NULL);
CREATE TABLE invoice_line (
 id INTEGER PRIMARY KEY, invoice_id INTEGER, line_total INTEGER,
 from_booking_fee INTEGER
);
INSERT INTO invoice_line VALUES (1,1,30000,0), (2,2,10000,1);
CREATE TABLE time_entry (id INTEGER PRIMARY KEY, task_id INTEGER,
 billed INTEGER, invoice_line_id INTEGER);
INSERT INTO time_entry VALUES (1,1,1,1), (2,1,1,999);
CREATE TABLE task_item (id INTEGER PRIMARY KEY, task_id INTEGER,
 billed INTEGER, invoice_line_id INTEGER);
INSERT INTO task_item VALUES (1,1,1,1);
CREATE TABLE quote (id INTEGER PRIMARY KEY, job_id INTEGER,
 state TEXT, total_amount INTEGER);
INSERT INTO quote VALUES (1,1,'invoiced',100000);
CREATE TABLE quote_line_group (id INTEGER PRIMARY KEY, quote_id INTEGER,
 task_id INTEGER, line_approval_status TEXT);
INSERT INTO quote_line_group VALUES (1,1,1,'approved');
CREATE TABLE quote_line (id INTEGER PRIMARY KEY, quote_id INTEGER);
CREATE TABLE milestone (id INTEGER PRIMARY KEY, quote_id INTEGER,
 invoice_id INTEGER, payment_amount INTEGER, voided INTEGER);
INSERT INTO milestone VALUES (1,1,1,30000,0),(2,1,NULL,70000,0);
CREATE TABLE debtor_payment_allocation (id INTEGER PRIMARY KEY,
 invoice_id INTEGER, allocated_date TEXT);
CREATE TABLE quickbooks_invoice_export (invoice_id INTEGER PRIMARY KEY,
 external_id TEXT);
