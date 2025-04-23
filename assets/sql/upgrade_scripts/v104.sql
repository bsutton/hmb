-- Add an 'assumption' field to the Job table
ALTER TABLE job
  ADD COLUMN assumption TEXT NOT NULL DEFAULT '';

-- Add an 'assumption' field to the Task table
ALTER TABLE task
  ADD COLUMN assumption TEXT NOT NULL DEFAULT '';
