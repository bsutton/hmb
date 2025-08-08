
-- Step 1: Add new column to store enum ID as string
ALTER TABLE job ADD COLUMN status_id TEXT;

-- Step 2: Migrate existing job_status_id to string enum (assuming job_status table still exists temporarily)
UPDATE job
SET status_id = (
  SELECT REPLACE(js.name, ' ', '')
  FROM job_status js
  WHERE js.id = job.job_status_id
);

-- Step 3: Remove foreign key column
ALTER TABLE job DROP COLUMN job_status_id;


-- Step 4: (Optional) Drop job_status table if no longer needed
DROP TABLE job_status;


