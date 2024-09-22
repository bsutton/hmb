
-- add missing links after v50.sql didn't create them
-- Insert into check_list_check_list_item to create a link
INSERT INTO check_list_check_list_item (
    check_list_id,
    check_list_item_id,
    createdDate,
    modifiedDate
)
SELECT 
    cl.id,                                  -- check_list_id
    cli.id,                                 -- newly created check_list_item_id
    datetime('now'),                        -- Created date
    datetime('now')                         -- Modified date
FROM check_list cl
JOIN check_list_item cli ON cl.id = cli.check_list_id
JOIN task t ON t.id = (SELECT task_id FROM task_check_list WHERE check_list_id = cl.id LIMIT 1)
WHERE cli.description = 'Action for Effort in Hours';


-- add missing links after v50.sql didn't create them
-- Insert into check_list_check_list_item to create a link
INSERT INTO check_list_check_list_item (
    check_list_id,
    check_list_item_id,
    createdDate,
    modifiedDate
)
SELECT 
    cl.id,                                  -- check_list_id
    cli.id,                                 -- newly created check_list_item_id
    datetime('now'),                        -- Created date
    datetime('now')                         -- Modified date
FROM check_list cl
JOIN check_list_item cli ON cl.id = cli.check_list_id
JOIN task t ON t.id = (SELECT task_id FROM task_check_list WHERE check_list_id = cl.id LIMIT 1)
WHERE cli.description = 'Action for Estimated Cost';


-- remove the old task columns
-- Step 1: Rename the existing table
ALTER TABLE task RENAME TO task_old;

-- Step 2: Create the new task table without 'effort_in_hours' and 'estimated_cost' columns
CREATE TABLE task (
    id INTEGER PRIMARY KEY,
    job_id INTEGER,
    name TEXT,
    description TEXT,
    task_status_id INTEGER,
    createdDate TEXT,
    modifiedDate TEXT,
    billing_type TEXT,
    FOREIGN KEY (job_id) REFERENCES job(id),
    FOREIGN KEY (task_status_id) REFERENCES task_status(id)
);

-- Step 3: Copy data from the old table to the new table
INSERT INTO task (id, job_id, name, description, task_status_id, createdDate, modifiedDate, billing_type)
SELECT id, job_id, name, description, task_status_id, createdDate, modifiedDate, billing_type
FROM task_old;

-- Step 4: Drop the old table
DROP TABLE task_old;

-- Step 5: Rename the new table to the original table name
-- This step is actually unnecessary in this case, as the table has already been created with the desired name.

-- original calc didn't account for the fact we store 3 decimals as a int.

-- UPDATE check_list_item 
-- SET estimated_material_unit_cost = estimated_material_unit_cost / 1000 
-- WHERE description = 'Action for Estimated Cost';

UPDATE check_list_item 
SET 
estimated_material_unit_cost = estimated_material_unit_cost /1000,
estimated_labour_cost = estimated_labour_cost / 1000 ,
estimated_material_quantity = estimated_material_quantity * 100
WHERE description = 'Action for Effort in Hours';


