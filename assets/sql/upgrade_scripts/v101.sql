-- 1. Rename the existing table.
ALTER TABLE quote
    RENAME TO quote_old;
-- 2. Create the new table with the updated constraint and new column name.
CREATE TABLE quote (
    id INTEGER PRIMARY KEY,
    job_id INTEGER,
    total_amount INTEGER,
    created_date TEXT,
    modified_date TEXT,
    quote_num TEXT,
    external_quote_id TEXT,
    -- Updated state column: allowed values include 'approved'
    state TEXT NOT NULL DEFAULT 'reviewing' CHECK (
        state IN ('reviewing', 'sent', 'rejected', 'approved')
    ),
    date_sent TEXT,
    date_approved TEXT
);
-- 3. Copy the data from the old table into the new table.
INSERT INTO quote (
        id,
        job_id,
        total_amount,
        created_date,
        modified_date,
        quote_num,
        external_quote_id,
        state,
        date_sent,
        date_approved
    )
SELECT id,
    job_id,
    total_amount,
    created_date,
    modified_date,
    quote_num,
    external_quote_id,
    state,
    date_sent,
    date_accepted -- Copy old date_accepted into new date_approved column
FROM quote_old;
-- 4. Drop the old table.
DROP TABLE quote_old;