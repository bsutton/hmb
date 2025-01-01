-- job_event_table.sql
CREATE TABLE IF NOT EXISTS job_event (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    job_id INTEGER NOT NULL,
    start_date TEXT NOT NULL,
    end_date TEXT NOT NULL,
    created_date TEXT NOT NULL,
    modified_date TEXT NOT NULL,
    FOREIGN KEY (job_id) REFERENCES job (id) ON DELETE CASCADE ON UPDATE CASCADE
);