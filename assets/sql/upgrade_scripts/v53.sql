-- move data from task to check_list_items
-- Insert check_list_item for tasks with effort_in_hours
INSERT INTO check_list_item (
    check_list_id,
    description,
    item_type_id,
    estimated_material_unit_cost,
    estimated_labour_hours,
    estimated_material_quantity,
    completed,
    billed,
    createdDate,
    modifiedDate,
    measurement_type,
    dimension1,
    dimension2,
    dimension3,
    units,
    url,
    supplier_id,
    estimated_labour_cost
)
SELECT 
    cl.id,                                  -- Use existing check_list_id
    'Action for Effort in Hours',           -- Description
    5,                                      -- Labour item type
    0,                                      -- No material unit cost
    t.effort_in_hours,                      -- Labour hours from task
    1,                                      -- Default quantity
    0,                                      -- Not completed
    0,                                      -- Not billed
    datetime('now'),                        -- Created date
    datetime('now'),                        -- Modified date
    NULL,                                   -- Measurement type
    0,                                      -- Dimension1
    0,                                      -- Dimension2
    0,                                      -- Dimension3
    '',                                     -- Units
    '',                                     -- URL
    NULL,                                   -- Supplier ID
    0                                       -- Estimated labour cost
FROM task t
JOIN task_check_list tcl ON t.id = tcl.task_id
JOIN check_list cl ON tcl.check_list_id = cl.id
WHERE t.effort_in_hours IS NOT NULL AND t.effort_in_hours > 0;

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

-- Insert check_list_item for tasks with estimated_cost
INSERT INTO check_list_item (
    check_list_id,
    description,
    item_type_id,
    estimated_material_unit_cost,
    estimated_labour_hours,
    estimated_material_quantity,
    completed,
    billed,
    createdDate,
    modifiedDate,
    measurement_type,
    dimension1,
    dimension2,
    dimension3,
    units,
    url,
    supplier_id,
    estimated_labour_cost
)
SELECT 
    cl.id,                                  -- Use existing check_list_id
    'Action for Estimated Cost',            -- Description
    5,                                      -- Labour item type
    0,                                      -- No material unit cost
    0,                                      -- No labour hours
    1,                                      -- Default quantity
    0,                                      -- Not completed
    0,                                      -- Not billed
    datetime('now'),                        -- Created date
    datetime('now'),                        -- Modified date
    NULL,                                   -- Measurement type
    0,                                      -- Dimension1
    0,                                      -- Dimension2
    0,                                      -- Dimension3
    '',                                     -- Units
    '',                                     -- URL
    NULL,                                   -- Supplier ID
    t.estimated_cost                        -- Estimated cost from task
FROM task t
JOIN task_check_list tcl ON t.id = tcl.task_id
JOIN check_list cl ON tcl.check_list_id = cl.id
WHERE t.estimated_cost IS NOT NULL AND t.estimated_cost > 0;

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
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  -- List other columns in the task table excluding 'effort_in_hours' and 'estimated_cost'
  name TEXT NOT NULL,
  description TEXT,
  job_id INTEGER,
  -- Add other necessary columns here
  createdDate TEXT NOT NULL,
  modifiedDate TEXT NOT NULL,
  FOREIGN KEY (job_id) REFERENCES job(id)
);

-- Step 3: Copy data from the old table to the new table
INSERT INTO task (id, name, description, job_id, createdDate, modifiedDate)
SELECT id, name, description, job_id, createdDate, modifiedDate
FROM task_old;

-- Step 4: Drop the old table
DROP TABLE task_old;

