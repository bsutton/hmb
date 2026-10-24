CREATE TABLE job (id INTEGER PRIMARY KEY);
INSERT INTO job VALUES (1);
CREATE TABLE job_billing_state (
  job_id INTEGER PRIMARY KEY, revision INTEGER, checked_revision INTEGER,
  attempts INTEGER, retry_after INTEGER, failed INTEGER
);
INSERT INTO job_billing_state VALUES (1, 5, 5, 3, 100, 1);
