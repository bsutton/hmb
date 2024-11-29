CREATE TABLE payment_terms (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  quote_id INTEGER NOT NULL,
  payment_number INTEGER NOT NULL,
  payment_percentage REAL,
  payment_amount INTEGER,
  milestone_description TEXT,
  due_date TEXT,
  status TEXT DEFAULT 'pending',
  FOREIGN KEY (quote_id) REFERENCES quote(id) ON DELETE CASCADE
);
