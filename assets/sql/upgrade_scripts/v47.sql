ALTER TABLE task_status
ADD COLUMN ordinal INTEGER;

UPDATE task_status
SET ordinal = CASE 
    WHEN name = 'To be scheduled' THEN 1  -- To be scheduled
    WHEN name = 'In progress' THEN 2      -- In progress
    WHEN name = 'On Hold' THEN 3          -- On Hold
    WHEN name = 'Awaiting Materials' THEN 4 -- Awaiting Materials
    WHEN name = 'Completed' THEN 5        -- Completed
    WHEN name = 'Cancelled' THEN 6        -- Cancelled
    ELSE ordinal -- Ensures other rows are not affected
END;

UPDATE task_status
SET name = CASE 
    WHEN name = 'in progress' THEN 'In Progress'
    WHEN name = 'to be scheduled' THEN 'To Be Scheduled'
    ELSE name -- Ensures other rows are not affected
END;

ALTER TABLE job
ADD COLUMN billing_type TEXT;

UPDATE job
SET billing_type = 'timeAndMaterial'; 

ALTER TABLE task
ADD COLUMN billing_type TEXT;

UPDATE task
SET billing_type = 'timeAndMaterial'; -- Or any other default billing type




