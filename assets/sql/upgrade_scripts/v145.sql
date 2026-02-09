-- Allow closed ToDo items while keeping existing data.
ALTER TABLE to_do RENAME TO to_do_old;

CREATE TABLE to_do (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  title           TEXT    NOT NULL,
  note            TEXT,
  due_date        TEXT,
  remind_at       TEXT,
  priority        TEXT    NOT NULL DEFAULT 'none'
                    CHECK (priority IN ('none','low','medium','high')),
  status          TEXT    NOT NULL DEFAULT 'open'
                    CHECK (status IN ('open','done','closed')),
  parent_type     TEXT
                    CHECK (parent_type IN ('job','customer') OR parent_type IS NULL),
  parent_id       INTEGER,
  created_date    TEXT    NOT NULL,
  modified_date   TEXT    NOT NULL,
  completed_date  TEXT,
  CHECK (
    (parent_type IS NULL AND parent_id IS NULL) OR
    (parent_type IS NOT NULL AND parent_id IS NOT NULL)
  )
);

INSERT INTO to_do (
  id, title, note, due_date, remind_at, priority, status,
  parent_type, parent_id, created_date, modified_date, completed_date
)
SELECT
  id, title, note, due_date, remind_at, priority, status,
  parent_type, parent_id, created_date, modified_date, completed_date
FROM to_do_old;

DROP TABLE to_do_old;

CREATE INDEX IF NOT EXISTS idx_to_do_status_due
  ON to_do(status, due_date);
CREATE INDEX IF NOT EXISTS idx_to_do_parent
  ON to_do(parent_type, parent_id);
CREATE INDEX IF NOT EXISTS idx_to_do_remind
  ON to_do(remind_at);
CREATE INDEX IF NOT EXISTS idx_to_do_open_due_only
  ON to_do(due_date)
  WHERE status = 'open' AND due_date IS NOT NULL;
