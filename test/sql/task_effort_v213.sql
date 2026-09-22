CREATE TABLE category (id INTEGER PRIMARY KEY, name TEXT NOT NULL);
CREATE TABLE task (
  id INTEGER PRIMARY KEY, job_id INTEGER NOT NULL, name TEXT NOT NULL,
  description TEXT NOT NULL, task_status_id INTEGER NOT NULL,
  createdDate TEXT NOT NULL, modifiedDate TEXT NOT NULL
);
INSERT INTO task VALUES
  (1, 1, 'Existing work', '', 6, '2026-01-01', '2026-01-01');
