
update task
set task_status_id = 3 
where task_status_id > 8;

-- Renumber TaskStatus IDs to 1..7 and remap task.task_status_id

-- 1) Shift ids out of the way to avoid unique/PK collisions
UPDATE task SET task_status_id = task_status_id + 100;

UPDATE task
SET task_status_id = CASE task_status_id
  WHEN 101 THEN 1  -- Awaiting Approval (old 1)
  WHEN 107 THEN 1  -- Awaiting Approval (old 7)
  WHEN 108 THEN 2  -- Approved         (old 8)
  WHEN 105 THEN 3  -- In Progress      (old 5)
  WHEN 102 THEN 4  -- Awaiting Materials (old 2)
  WHEN 104 THEN 5  -- On Hold          (old 4)
  WHEN 103 THEN 6  -- Completed        (old 3)
  WHEN 106 THEN 7  -- Cancelled        (old 6)
  ELSE task_status_id
END;


ALTER TABLE "Tool" RENAME TO "tmptool";
ALTER TABLE "tmptool" RENAME TO "tool";



