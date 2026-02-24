CREATE TABLE backup_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  provider TEXT NOT NULL,
  operation TEXT NOT NULL,
  success INTEGER NOT NULL,
  error TEXT,
  occurred_at TEXT NOT NULL,
  created_date TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  modified_date TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX backup_history_op_success_when_idx
ON backup_history(operation, success, occurred_at DESC);
