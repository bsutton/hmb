CREATE TABLE job_source_email (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  job_id INTEGER NOT NULL UNIQUE,
  account_email TEXT NOT NULL,
  message_id TEXT NOT NULL,
  thread_id TEXT,
  sender_email TEXT NOT NULL DEFAULT '',
  subject TEXT NOT NULL DEFAULT '',
  received_at TEXT NOT NULL,
  created_date TEXT NOT NULL,
  modified_date TEXT NOT NULL,
  FOREIGN KEY (job_id) REFERENCES job(id) ON DELETE CASCADE,
  UNIQUE (account_email, message_id)
);
