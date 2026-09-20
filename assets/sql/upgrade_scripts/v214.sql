-- Durable, coalescing billing checks. No triggers or invoice-link changes.
CREATE TABLE job_billing_state (
  job_id INTEGER PRIMARY KEY REFERENCES job(id) ON DELETE CASCADE,
  billing_required INTEGER NOT NULL DEFAULT 1,
  revision INTEGER NOT NULL DEFAULT 1,
  checked_revision INTEGER NOT NULL DEFAULT 0,
  attempts INTEGER NOT NULL DEFAULT 0,
  retry_after INTEGER NOT NULL DEFAULT 0,
  checked_at INTEGER,
  failed INTEGER NOT NULL DEFAULT 0,
  reason TEXT
);
CREATE INDEX job_billing_pending
  ON job_billing_state(retry_after)
  WHERE revision != checked_revision;
-- Existing source billing flags are preserved. Reconcile once in background.
INSERT INTO job_billing_state(job_id)
  SELECT id FROM job WHERE is_stock = 0;
