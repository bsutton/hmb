-- Add 'withdrawn' as a valid quote state.
ALTER TABLE quote RENAME TO quote_old;

CREATE TABLE quote (
    id INTEGER PRIMARY KEY,
    job_id INTEGER,
    total_amount INTEGER,
    created_date TEXT,
    modified_date TEXT,
    quote_num TEXT,
    external_quote_id TEXT,
    state TEXT NOT NULL DEFAULT 'reviewing' CHECK (
        state IN (
            'reviewing',
            'sent',
            'rejected',
            'withdrawn',
            'approved',
            'invoiced'
        )
    ),
    date_sent TEXT,
    date_approved TEXT,
    assumption TEXT NOT NULL DEFAULT '',
    billing_contact_id INTEGER,
    summary TEXT NOT NULL DEFAULT '',
    description TEXT NOT NULL DEFAULT ''
);

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
    date_approved,
    assumption,
    billing_contact_id,
    summary,
    description
)
SELECT
    id,
    job_id,
    total_amount,
    created_date,
    modified_date,
    quote_num,
    external_quote_id,
    state,
    date_sent,
    date_approved,
    assumption,
    billing_contact_id,
    summary,
    description
FROM quote_old;

DROP TABLE quote_old;
