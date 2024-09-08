alter table job_status add column ordinal int not null default 0;

UPDATE job_status
SET ordinal = CASE 
    WHEN id = 1 THEN 1  -- Prospecting
    WHEN id = 7 THEN 2  -- Rejected
    WHEN id = 2 THEN 3  -- To be Scheduled
    WHEN id = 11 THEN 4 -- Scheduled
    WHEN id = 9 THEN 5  -- In Progress
    WHEN id = 8 THEN 6  -- On Hold
    WHEN id = 3 THEN 7  -- Awaiting Materials
    WHEN id = 6 THEN 8  -- Progress Payment
    WHEN id = 4 THEN 9  -- Completed
    WHEN id = 10 THEN 10 -- Awaiting Payment
    WHEN id = 5 THEN 11 -- To be Billed
    ELSE ordinal -- Ensures other rows are not affected
END;