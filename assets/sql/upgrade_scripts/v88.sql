ALTER TABLE task_item
ADD COLUMN charge_set INTEGER DEFAULT 0;
UPDATE task_item
SET charge_set = 1
WHERE charge IS NOT NULL;