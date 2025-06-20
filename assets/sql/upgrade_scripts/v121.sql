-- Add `purpose` column to task_item table
ALTER TABLE task_item ADD COLUMN purpose TEXT DEFAULT '';
