
-- 1. Create the new table with id, timestamps, and FKs
CREATE TABLE supplier_assignment_task_new (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  assignment_id  INTEGER NOT NULL,
  task_id        INTEGER NOT NULL,
  created_date   TEXT    NOT NULL DEFAULT (datetime('now')),
  modified_date  TEXT    NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (assignment_id) REFERENCES supplier_assignment(id),
  FOREIGN KEY (task_id)       REFERENCES task(id)
);

-- 3. Drop the old table
DROP TABLE supplier_assignment_task;

-- 4. Rename the new table into place
ALTER TABLE supplier_assignment_task_new
  RENAME TO supplier_assignment_task;

-- 5. Recreate index on assignment_id
CREATE INDEX idx_sat_assignment
  ON supplier_assignment_task(assignment_id);



