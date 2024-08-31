INSERT INTO job_status (name, description, color_code, hidden,createdDate, modifiedDate, ordinal)
VALUES ('Quoting', 'Preparing a quote for the job', '#ADD8E6', 0, datetime('now'), datetime('now'), 2);

UPDATE job_status
SET ordinal = CASE 
    WHEN name = 'Prospecting' THEN 1      -- Remains the first status
    WHEN name = 'Quoting' THEN 2        -- New status
    WHEN name = 'To be Scheduled' THEN 3  -- Shifted to 3rd position
    WHEN name = 'Scheduled' THEN 4        -- Shifted to 4th position
    WHEN name = 'In Progress' THEN 5      -- Shifted to 5th position
    WHEN name = 'On Hold' THEN 6          -- Shifted to 6th position
    WHEN name = 'Awaiting Materials' THEN 7 -- Shifted to 7th position
    WHEN name = 'Progress Payment' THEN 8 -- Shifted to 8th position
    WHEN name = 'Completed' THEN 9        -- Shifted to 9th position
    WHEN name = 'Awaiting Payment' THEN 10 -- Shifted to 10th position
    WHEN name = 'To be Billed' THEN 11    -- Shifted to 11th position
    WHEN name = 'Rejected' THEN 12        -- Shifted to 12th position
    ELSE ordinal
END;

