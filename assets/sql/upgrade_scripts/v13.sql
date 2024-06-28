CREATE TABLE invoice (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  job_id INTEGER NOT NULL,
  total_amount INTEGER NOT NULL,
  created_date TEXT NOT NULL,
  modified_date TEXT NOT NULL,
  FOREIGN KEY(job_id) REFERENCES job(id)
);

CREATE TABLE invoice_line (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  invoice_id INTEGER NOT NULL,
  description TEXT NOT NULL,
  quantity INTEGER NOT NULL DEFAULT 0,
  unit_price INTEGER NOT NULL  DEFAULT 0,
  line_total INTEGER NOT NULL  DEFAULT 0,
  created_date TEXT NOT NULL,
  modified_date TEXT NOT NULL,
  FOREIGN KEY(invoice_id) REFERENCES invoice(id)
);
