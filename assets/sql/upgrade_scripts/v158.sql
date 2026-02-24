CREATE TABLE task_approval (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  job_id         INTEGER NOT NULL,
  contact_id     INTEGER NOT NULL,
  status         INTEGER NOT NULL DEFAULT 0,
  created_date   TEXT    NOT NULL,
  modified_date  TEXT    NOT NULL,
  FOREIGN KEY (job_id) REFERENCES job(id),
  FOREIGN KEY (contact_id) REFERENCES contact(id)
);

CREATE INDEX task_approval_job_id_idx
  ON task_approval(job_id);

CREATE TABLE task_approval_task (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  approval_id    INTEGER NOT NULL,
  task_id        INTEGER NOT NULL,
  status         INTEGER NOT NULL DEFAULT 0,
  created_date   TEXT    NOT NULL,
  modified_date  TEXT    NOT NULL,
  FOREIGN KEY (approval_id) REFERENCES task_approval(id),
  FOREIGN KEY (task_id) REFERENCES task(id)
);

CREATE INDEX task_approval_task_approval_id_idx
  ON task_approval_task(approval_id);

CREATE INDEX task_approval_task_task_id_idx
  ON task_approval_task(task_id);
