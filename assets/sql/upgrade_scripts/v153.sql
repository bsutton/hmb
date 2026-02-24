CREATE TABLE job_attachment (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  job_id INTEGER NOT NULL REFERENCES job(id) ON DELETE CASCADE,
  file_path TEXT NOT NULL,
  display_name TEXT NOT NULL,
  created_date TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  modified_date TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX job_attachment_unique_path
ON job_attachment(job_id, file_path);
