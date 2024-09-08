-- We are moving estimates into check list items.
-- associated with a task.
-- Insert CheckListItem for tasks with effort_in_hours, using job's hourly rate for cost
INSERT INTO check_list_item (
    check_list_id,
    description,
    item_type_id,
    effort_in_hours,
    unit_cost,
    quantity,
    completed,
    billed,
    createdDate,
    modifiedDate
)
SELECT 
    tcl.check_list_id,                             -- The associated checklist
    'Action for Effort in Hours',                  -- Description for effort_in_hours action
    5,                                             -- Action item type ID (from check_list_item_type table)
    t.effort_in_hours,                             -- Effort in hours from the task
    (j.hourly_rate * t.effort_in_hours),           -- Unit cost based on job's hourly rate multiplied by effort_in_hours
    1,                                             -- Default quantity
    0,                                             -- Not completed
    0,                                             -- Not billed
    NOW(),                                         -- Created Date
    NOW()                                          -- Modified Date
FROM task t
JOIN task_check_list tcl ON t.id = tcl.task_id
JOIN job j ON t.job_id = j.id
WHERE t.effort_in_hours IS NOT NULL 
  AND t.effort_in_hours > 0;

-- Insert CheckListItem for tasks with estimated_cost
INSERT INTO check_list_item (
    check_list_id,
    description,
    item_type_id,
    effort_in_hours,
    unit_cost,
    quantity,
    completed,
    billed,
    createdDate,
    modifiedDate
)
SELECT 
    tcl.check_list_id,                             -- The associated checklist
    'Action for Estimated Cost',                   -- Description for estimated_cost action
    5,                                             -- Action item type ID (from check_list_item_type table)
    0,                                             -- No effort in hours associated
    t.estimated_cost,                              -- Estimated cost from the task
    1,                                             -- Default quantity
    0,                                             -- Not completed
    0,                                             -- Not billed
    NOW(),                                         -- Created Date
    NOW()                                          -- Modified Date
FROM task t
JOIN task_check_list tcl ON t.id = tcl.task_id
WHERE t.estimated_cost IS NOT NULL 
  AND t.estimated_cost > 0;
