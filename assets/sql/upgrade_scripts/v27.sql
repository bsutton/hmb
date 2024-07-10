CREATE TABLE quote (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  job_id INTEGER NOT NULL,
  total_amount INTEGER NOT NULL,
  created_date TEXT NOT NULL,
  modified_date TEXT NOT NULL,
  quote_num TEXT,
  external_quote_id TEXT,
  FOREIGN KEY (job_id) REFERENCES job (id)
);

CREATE TABLE quote_line (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  quote_id INTEGER NOT NULL,
  quote_line_group_id INTEGER,
  description TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  unit_price INTEGER NOT NULL,
  line_total INTEGER NOT NULL,
  created_date TEXT NOT NULL,
  modified_date TEXT NOT NULL,
  status INTEGER NOT NULL,
  FOREIGN KEY (quote_id) REFERENCES quote (id),
  FOREIGN KEY (quote_line_group_id) REFERENCES quote_line_group (id)
);



CREATE TABLE quote_line_group (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  quote_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  created_date TEXT NOT NULL,
  modified_date TEXT NOT NULL,
  FOREIGN KEY (quote_id) REFERENCES quote (id)
);
