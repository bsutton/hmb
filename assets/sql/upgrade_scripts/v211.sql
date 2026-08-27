CREATE TABLE lifecycle_transition (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  aggregate_type TEXT NOT NULL,
  aggregate_id INTEGER NOT NULL,
  job_id INTEGER NOT NULL,
  event TEXT NOT NULL,
  from_state TEXT NOT NULL,
  to_state TEXT NOT NULL,
  source TEXT NOT NULL,
  reason TEXT,
  actor_id TEXT,
  correlation_id TEXT NOT NULL,
  occurred_at TEXT NOT NULL
);

CREATE INDEX lifecycle_transition_job_time
  ON lifecycle_transition(job_id, occurred_at DESC);

CREATE INDEX lifecycle_transition_aggregate_time
  ON lifecycle_transition(
    aggregate_type,
    aggregate_id,
    occurred_at DESC
  );

UPDATE job
SET status_id = 'Completed'
WHERE status_id = 'ToBeBilled';
