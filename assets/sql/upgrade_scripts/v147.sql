-- Normalize task billing type to inherited when it matches the parent job.
-- This fixes tasks that were unintentionally saved with explicit values.
UPDATE task
SET billing_type = NULL
WHERE billing_type IS NOT NULL
  AND billing_type = (
    SELECT j.billing_type
    FROM job j
    WHERE j.id = task.job_id
  );
