-- 1) flag that something was returned
ALTER TABLE task_item ADD COLUMN returned INTEGER    NOT NULL DEFAULT 0;
-- 2) how many units were returned (minor‐units)
ALTER TABLE task_item ADD COLUMN return_quantity INTEGER;
-- 3) refund amount per unit (minor‐units)
ALTER TABLE task_item ADD COLUMN return_unit_price INTEGER;
-- 4) timestamp of the return
ALTER TABLE task_item ADD COLUMN return_date TEXT;
