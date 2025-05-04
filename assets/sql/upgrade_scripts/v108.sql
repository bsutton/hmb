-- 1) Create new table without billing_contact_id
CREATE TABLE milestone_new (
    id INTEGER PRIMARY KEY,
    quote_id INTEGER NOT NULL,
    milestone_number INTEGER NOT NULL,
    payment_amount INTEGER NOT NULL,
    payment_percentage INTEGER NOT NULL,
    invoice_id INTEGER,
    milestone_description TEXT,
    due_date TEXT,
    edited INTEGER NOT NULL,
    created_date TEXT NOT NULL,
    modified_date TEXT NOT NULL
);
-- 2) Copy data over (omitting billing_contact_id)
INSERT INTO milestone_new (
        id,
        quote_id,
        milestone_number,
        payment_amount,
        payment_percentage,
        invoice_id,
        milestone_description,
        due_date,
        edited,
        created_date,
        modified_date
    )
SELECT id,
    quote_id,
    milestone_number,
    payment_amount,
    payment_percentage,
    invoice_id,
    milestone_description,
    due_date,
    edited,
    created_date,
    modified_date
FROM milestone;
-- 3) Drop the old table
DROP TABLE milestone;
-- 4) Rename the new table back to milestone
ALTER TABLE milestone_new
    RENAME TO milestone;


-- 1) Add the new nullable column to the existing table
ALTER TABLE job
ADD COLUMN billing_contact_id INTEGER;

