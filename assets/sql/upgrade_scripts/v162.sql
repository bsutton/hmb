CREATE TABLE activity (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  job_id INTEGER NOT NULL REFERENCES job(id) ON DELETE CASCADE,
  occurred_at TEXT NOT NULL,
  type TEXT NOT NULL,
  summary TEXT NOT NULL,
  details TEXT,
  source TEXT NOT NULL DEFAULT 'manual',
  linked_todo_id INTEGER REFERENCES to_do(id) ON DELETE SET NULL,
  created_date TEXT NOT NULL,
  modified_date TEXT NOT NULL
);

CREATE INDEX activity_job_occurred_idx
ON activity(job_id, occurred_at DESC, id DESC);

CREATE INDEX activity_linked_todo_idx
ON activity(linked_todo_id);
