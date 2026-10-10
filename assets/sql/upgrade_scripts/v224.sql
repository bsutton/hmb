-- Preserve cancelled bookings for history and durable cleanup retries.
CREATE TABLE cancelled_schedule (
  activity_id INTEGER PRIMARY KEY,
  job_id INTEGER NOT NULL,
  activity_json TEXT NOT NULL,
  calendar_pending INTEGER NOT NULL DEFAULT 1,
  reminder_pending INTEGER NOT NULL DEFAULT 1
);
