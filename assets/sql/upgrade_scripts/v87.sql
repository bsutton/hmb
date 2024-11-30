-- Step 1: Rename the existing table
ALTER TABLE milestone_payment RENAME TO milestone_payment_old;

-- Step 2: Create the new table with the desired schema
CREATE TABLE milestone (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  quote_id INTEGER NOT NULL,
  milestone_number INTEGER NOT NULL,
  payment_percentage INTEGER,
  payment_amount INTEGER,
  milestone_description TEXT,
  due_date TEXT,
  status TEXT DEFAULT 'pending',
  created_date TEXT NOT NULL,
  modified_date TEXT NOT NULL,
  invoice_id INTEGER, -- New column added
  FOREIGN KEY (quote_id) REFERENCES quote(id) ON DELETE CASCADE
);

-- Step 3: Copy the data from the old table to the new table
INSERT INTO milestone (
  id,
  quote_id,
  milestone_number,
  payment_percentage,
  payment_amount,
  milestone_description,
  due_date,
  status,
  created_date,
  modified_date
)
SELECT
  id,
  quote_id,
  milestone_number,
  payment_percentage,
  payment_amount,
  milestone_description,
  due_date,
  status,
  created_date,
  modified_date
FROM milestone_payment_old;

-- Step 4: Drop the old table
DROP TABLE milestone_payment_old;
