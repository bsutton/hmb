CREATE TABLE job (
  id INTEGER PRIMARY KEY, is_stock INTEGER NOT NULL,
  booking_fee_invoiced INTEGER NOT NULL
);
INSERT INTO job VALUES (1, 0, 1), (2, 0, 0), (3, 1, 0);
CREATE TABLE milestone (id INTEGER PRIMARY KEY, quote_id INTEGER, invoice_id INTEGER);
INSERT INTO milestone VALUES (1, 7, 9);
