-- Create a new table without the start_date column
CREATE TABLE job_new (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    customer_id INTEGER,
    summary TEXT NOT NULL,
    description TEXT NOT NULL,
    site_id INTEGER,
    contact_id INTEGER,
    job_status_id INTEGER,
    hourly_rate INTEGER,
    booking_fee INTEGER,
    last_active INTEGER NOT NULL DEFAULT 0,
    billing_type TEXT NOT NULL DEFAULT 'timeAndMaterial',
    booking_fee_invoiced INTEGER NOT NULL DEFAULT 0,
    created_date TEXT NOT NULL,
    modified_date TEXT NOT NULL
);
-- Copy data from the old table to the new table
INSERT INTO job_new (
        id,
        customer_id,
        summary,
        description,
        site_id,
        contact_id,
        job_status_id,
        hourly_rate,
        booking_fee,
        last_active,
        billing_type,
        booking_fee_invoiced,
        created_date,
        modified_date
    )
SELECT id,
    customer_id,
    summary,
    description,
    site_id,
    contact_id,
    job_status_id,
    hourly_rate,
    booking_fee,
    last_active,
    billing_type,
    booking_fee_invoiced,
    created_date,
    modified_date
FROM job;
-- Drop the old table
DROP TABLE job;
-- Rename the new table to the old table's name
ALTER TABLE job_new
    RENAME TO job;