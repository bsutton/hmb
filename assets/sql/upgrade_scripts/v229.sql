-- Waiving unbilled work does not create an invoice or mark its sources billed.
CREATE TABLE billing_waiver (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  job_id INTEGER NOT NULL REFERENCES job(id) ON DELETE CASCADE,
  source_type TEXT NOT NULL CHECK(source_type IN
    ('time', 'item', 'milestone', 'quote', 'task_scope', 'booking_fee')),
  source_id INTEGER NOT NULL,
  source_hash TEXT NOT NULL,
  description TEXT NOT NULL,
  amount INTEGER NOT NULL CHECK(amount >= 0),
  reason TEXT NOT NULL CHECK(length(trim(reason)) > 0),
  waived_date TEXT NOT NULL,
  restored_date TEXT
);
CREATE UNIQUE INDEX billing_waiver_active
ON billing_waiver(job_id, source_type, source_id, source_hash)
WHERE restored_date IS NULL;
CREATE INDEX billing_waiver_job ON billing_waiver(job_id, id);

-- Re-evaluate stored flags using the current billing rules after upgrading.
UPDATE job_billing_state SET revision = revision + 1,
  attempts = 0, retry_after = 0, failed = 0;
