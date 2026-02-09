-- Rename column total_charge -> total_line_charge
ALTER TABLE task_item
  RENAME COLUMN charge TO total_line_charge;

ALTER TABLE task
  ADD COLUMN internal_notes TEXT NOT NULL DEFAULT '';




-- Backfill: set task.billing_type = job.billing_type for all existing rows
-- Rationale: preserve current behavior for existing tasks.
UPDATE task
   SET billing_type = (
         SELECT job.billing_type
           FROM job
          WHERE job.id = task.job_id
       )
 WHERE billing_type IS NULL;


-- For tasks whose billing_type currently equals their job's type,
-- set to NULL so they inherit.
UPDATE task
SET billing_type = NULL
WHERE billing_type IS NOT NULL
  AND billing_type = (
    SELECT j.billing_type
    FROM job j
    WHERE j.id = task.job_id
  );
