CREATE TABLE invoice_line_group (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  invoice_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  created_date TEXT NOT NULL,
  modified_date TEXT NOT NULL,
  FOREIGN KEY(invoice_id) REFERENCES invoice(id)
);



-- Step 1: Rename the existing table
ALTER TABLE invoice_line RENAME TO invoice_line_old;

-- Step 2: Create a new table with the desired schema
CREATE TABLE invoice_line (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  invoice_id INTEGER NOT NULL,
  invoice_line_group_id INTEGER,
  description TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  unit_price INTEGER NOT NULL,
  line_total INTEGER NOT NULL,
  created_date TEXT NOT NULL,
  modified_date TEXT NOT NULL,
  FOREIGN KEY(invoice_id) REFERENCES invoice(id),
  FOREIGN KEY(invoice_line_group_id) REFERENCES invoice_line_group(id)
);

-- Step 3: Copy data from the old table to the new table
INSERT INTO invoice_line (id, invoice_id,  description, quantity, unit_price, line_total, created_date, modified_date)
SELECT id, invoice_id,  description, quantity, unit_price, line_total, created_date, modified_date
FROM invoice_line_old;

-- Step 4: Drop the old table
DROP TABLE invoice_line_old;