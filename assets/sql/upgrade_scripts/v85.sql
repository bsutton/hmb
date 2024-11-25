-- clean up the db when from failing to delete task items
-- when we deleted a task.
DELETE FROM task_item
WHERE task_id NOT IN (
    SELECT id
    FROM task
);
