DROP TABLE IF EXISTS milestone;

CREATE TABLE milestone (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  quote_id INTEGER NOT NULL,
  invoice_id INTEGER,
  milestone_number INTEGER NOT NULL,
  payment_amount INTEGER NOT NULL DEFAULT 0,
  payment_percentage INTEGER NOT NULL DEFAULT 0,
  milestone_description TEXT,
  due_date TEXT,
  edited INTEGER NOT NULL DEFAULT 0,
  created_date TEXT NOT NULL,
  modified_date TEXT NOT NULL,
  FOREIGN KEY (quote_id) REFERENCES quote(id) ON DELETE CASCADE
);
