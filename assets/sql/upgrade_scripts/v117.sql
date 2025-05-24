-- 1. Add the new columns with a sensible default
ALTER TABLE supplier_assignment_task
  ADD COLUMN created_date  TEXT NOT NULL
    DEFAULT (datetime('now'));

ALTER TABLE supplier_assignment_task
  ADD COLUMN modified_date TEXT NOT NULL
    DEFAULT (datetime('now'));