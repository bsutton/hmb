-- To-Dos
CREATE TABLE IF NOT EXISTS to_do (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  title           TEXT    NOT NULL,
  note            TEXT,

  -- ISO-8601 strings (e.g. 2025-08-10T09:30:00.000Z)
  due_date        TEXT,        -- nullable
  remind_at       TEXT,        -- nullable

  -- string enums
  priority        TEXT    NOT NULL DEFAULT 'none'
                    CHECK (priority IN ('none','low','medium','high')),
  status          TEXT    NOT NULL DEFAULT 'open'
                    CHECK (status   IN ('open','done')),

  -- Polymorphic association (Job/Customer/None)
  parent_type     TEXT
                    CHECK (parent_type IN ('job','customer') OR parent_type IS NULL),
  parent_id       INTEGER,

  -- bookkeeping (ISO-8601)
  created_date    TEXT    NOT NULL,
  modified_date   TEXT    NOT NULL,
  completed_date  TEXT,        -- set when status = 'done'

  -- Keep parent_type and parent_id in sync
  CHECK (
    (parent_type IS NULL AND parent_id IS NULL) OR
    (parent_type IS NOT NULL AND parent_id IS NOT NULL)
  )
);

-- Helpful indexes
CREATE INDEX IF NOT EXISTS idx_to_do_status_due
  ON to_do(status, due_date);

CREATE INDEX IF NOT EXISTS idx_to_do_parent
  ON to_do(parent_type, parent_id);

CREATE INDEX IF NOT EXISTS idx_to_do_remind
  ON to_do(remind_at);

-- (Optional but fast for list screens)
-- Only open items with a due date
CREATE INDEX IF NOT EXISTS idx_to_do_open_due_only
  ON to_do(due_date)
  WHERE status = 'open' AND due_date IS NOT NULL;

CREATE TABLE to_do_tag (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE
);
CREATE TABLE to_do_tag_map (
  to_do_id INTEGER NOT NULL,
  tag_id   INTEGER NOT NULL,
  PRIMARY KEY (to_do_id, tag_id)
);
