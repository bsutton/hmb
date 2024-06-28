CREATE TABLE invoice_line_group (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  invoice_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  created_date TEXT NOT NULL,
  modified_date TEXT NOT NULL,
  FOREIGN KEY(invoice_id) REFERENCES invoice(id)
);


ALTER TABLE invoice_line ADD COLUMN invoice_line_group_id INTEGER;
ALTER TABLE invoice_line ADD FOREIGN KEY (invoice_line_group_id) REFERENCES invoice_line_group(id);
