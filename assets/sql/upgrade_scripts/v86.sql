CREATE TABLE milestone_payment (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  quote_id INTEGER NOT NULL,
  milestone_number INTEGER NOT NULL,
  payment_percentage integer,
  payment_amount INTEGER,
  milestone_description TEXT,
  due_date TEXT,
  status TEXT DEFAULT 'pending',
  created_date TEXT NOT NULL,
  modified_date TEXT NOT NULL,
  FOREIGN KEY (quote_id) REFERENCES quote(id) ON DELETE CASCADE
);
