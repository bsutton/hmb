-- Add new columns
ALTER TABLE photo ADD COLUMN path_to_cloud_storage TEXT;
ALTER TABLE photo ADD COLUMN path_version INTEGER DEFAULT 1;

-- Set path_version = 1 for all existing rows
UPDATE photo SET path_version = 1;

-- Update path_to_cloud_storage based on yyyy-MM and filename
UPDATE photo
SET path_to_cloud_storage = 'photos/' || 
    substr(created_date, 1, 7) || '/' || 
    substr(filePath, length(filePath) - length(replace(filePath, '/', '')) + 1)
    WHERE last_backup_date IS NOT NULL;