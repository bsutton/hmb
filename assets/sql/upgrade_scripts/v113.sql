-- Step 1: Rename the old table
ALTER TABLE quote RENAME TO quote_old;

-- Step 2: Recreate the table with the updated CHECK constraint
CREATE TABLE quote (
    id INTEGER PRIMARY KEY,
    job_id INTEGER,
    total_amount INTEGER,
    created_date TEXT,
    modified_date TEXT,
    quote_num TEXT,
    external_quote_id TEXT,
    state TEXT NOT NULL DEFAULT 'reviewing' CHECK (
        state IN ('reviewing', 'sent', 'rejected', 'approved', 'invoiced')
    ),
    date_sent TEXT,
    date_approved TEXT,
    assumption TEXT NOT NULL DEFAULT '',
    billing_contact_id INTEGER
);

-- Step 3: Copy data from old table
INSERT INTO quote (
    id, job_id, total_amount, created_date, modified_date,
    quote_num, external_quote_id, state, date_sent, date_approved,
    assumption, billing_contact_id
)
SELECT
    id, job_id, total_amount, created_date, modified_date,
    quote_num, external_quote_id, state, date_sent, date_approved,
    assumption, billing_contact_id
FROM quote_old;

-- Step 4: Drop the old table
DROP TABLE quote_old;
