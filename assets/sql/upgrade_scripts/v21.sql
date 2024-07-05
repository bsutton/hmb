-- Step 1: Create the new table
CREATE TABLE new_task (
    id INTEGER PRIMARY KEY,
    jobId INTEGER NOT NULL,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    effort_in_hours INTEGER,
    estimated_cost INTEGER,
    task_status_id INTEGER NOT NULL,
    createdDate TEXT NOT NULL,
    modifiedDate TEXT NOT NULL
);

-- Step 2: Copy data from the old table to the new table
INSERT INTO new_task (id, jobId, name, description, effort_in_hours, estimated_cost, task_status_id, createdDate, modifiedDate)
SELECT id, jobId, name, description, effort_in_hours, estimated_cost, task_status_id, createdDate, modifiedDate
FROM task;

-- Step 3: Drop the old table
DROP TABLE task;

-- Step 4: Rename the new table to the old table's name
ALTER TABLE new_task RENAME TO task;
