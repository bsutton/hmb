-- Add columns to check_list_item table
ALTER TABLE check_list_item ADD COLUMN dimension_type TEXT;
ALTER TABLE check_list_item ADD COLUMN dimension1 int;
ALTER TABLE check_list_item ADD COLUMN dimension2 int;
ALTER TABLE check_list_item ADD COLUMN dimension3 int;

-- Add column to system table for unit system
ALTER TABLE system ADD COLUMN use_metric_units INTEGER DEFAULT 1;

-- Update dimensions to zero where they are NULL
UPDATE check_list_item
SET dimension1 = 0
WHERE dimension1 IS NULL;

UPDATE check_list_item
SET dimension2 = 0
WHERE dimension2 IS NULL;

UPDATE check_list_item
SET dimension3 = 0
WHERE dimension3 IS NULL;

-- Update description to an empty string where it is NULL
UPDATE check_list_item
SET description = ''
WHERE description IS NULL;

-- Update dimension type to 'length' where it is NULL
UPDATE check_list_item
SET dimension_type = 'length'
WHERE dimension_type IS NULL;

