CREATE TABLE IF NOT EXISTS accounting_sync_event (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  provider TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  local_id INTEGER,
  external_id TEXT,
  operation INTEGER NOT NULL,
  status INTEGER NOT NULL DEFAULT 0,
  last_attempt_at TEXT,
  attempt_count INTEGER NOT NULL DEFAULT 0,
  last_error TEXT,
  content_hash TEXT,
  payload TEXT,
  created_date TEXT NOT NULL DEFAULT (datetime('now')),
  modified_date TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS accounting_sync_event_pending_idx
  ON accounting_sync_event(provider, status, operation, created_date);

CREATE INDEX IF NOT EXISTS accounting_sync_event_entity_idx
  ON accounting_sync_event(provider, entity_type, local_id);

CREATE INDEX IF NOT EXISTS accounting_sync_event_external_idx
  ON accounting_sync_event(provider, entity_type, external_id);
