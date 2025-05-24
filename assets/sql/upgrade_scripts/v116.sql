-- 1a. the “assignment” header
CREATE TABLE supplier_assignment (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  job_id           INTEGER NOT NULL,
  supplier_id      INTEGER NOT NULL,
  contact_id        INTEGER NOT NULL,
  created_date     TEXT    NOT NULL,
  modified_date    TEXT    NOT NULL,
  FOREIGN KEY (job_id)      REFERENCES job(id),
  FOREIGN KEY (supplier_id) REFERENCES supplier(id)
);

-- 1b. the tasks assigned to that assignment
CREATE TABLE supplier_assignment_task (
  assignment_id INTEGER NOT NULL,
  task_id       INTEGER NOT NULL,
  PRIMARY KEY (assignment_id, task_id),
  FOREIGN KEY (assignment_id) REFERENCES supplier_assignment(id),
  FOREIGN KEY (task_id)       REFERENCES task(id)
);
