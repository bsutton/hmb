
-- make task related checklists confirm to the single default
-- task checklist
UPDATE check_list
SET name = 'default', description = 'Default Task Checklist'
WHERE id IN (
    SELECT cl.id
    FROM check_list cl
    JOIN task_check_list tcl ON cl.id = tcl.check_list_id
    JOIN task t ON tcl.task_id = t.id
);
