ALTER TABLE check_list_item ADD COLUMN units TEXT;

-- Update units to 'mm' where they are NULL or empty
UPDATE check_list_item
SET units = 'mm'
WHERE units IS NULL OR units = '';

