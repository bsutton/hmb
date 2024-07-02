-- Add a new column for the enumeration
ALTER TABLE job_status ADD COLUMN status_enum TEXT;

-- Update existing rows with appropriate new statuses
UPDATE job_status
SET status_enum = CASE
  WHEN name = 'Prospecting' THEN 'preStart'
  WHEN name = 'To be Scheduled' THEN 'preStart'
  WHEN name = 'Awaiting Materials' THEN 'onHold'
  WHEN name = 'Completed' THEN 'finalised'
  WHEN name = 'To be Billed' THEN 'finalised'
  WHEN name = 'Progress Payment' THEN 'finalised'
  WHEN name = 'Rejected' THEN 'onHold'
  WHEN name = 'On Hold' THEN 'onHold'
  WHEN name = 'In Progress' THEN 'progressing'
  WHEN name = 'Awaiting Payment' THEN 'onHold'
  WHEN name = 'Scheduled' THEN 'preStart'
  ELSE 'preStart' -- Default value if no match found
END;
