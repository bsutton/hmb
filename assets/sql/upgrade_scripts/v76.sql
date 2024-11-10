-- Rename the existing table
ALTER TABLE photo RENAME TO photo_old;

-- Create the new table with `parentId` and `parentType`
CREATE TABLE photo (
  id INTEGER PRIMARY KEY,
  parentId INTEGER NOT NULL,
  parentType TEXT NOT NULL,
  filePath TEXT NOT NULL,
  comment TEXT,
  created_date TEXT NOT NULL,
  modified_date TEXT NOT NULL
);

-- Copy data from the old table to the new one
INSERT INTO photo (id, parentId, parentType, filePath, comment, created_date, modified_date)
SELECT id, taskId AS parentId, 'task' AS parentType, filePath, comment, created_date, modified_date
FROM photo_old;

-- Drop the old table
DROP TABLE photo_old;
