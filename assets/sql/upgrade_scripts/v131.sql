
-- 1) Create the new table with the corrected schema.
CREATE TABLE IF NOT EXISTS photo_new (
  id                    INTEGER PRIMARY KEY AUTOINCREMENT,
  parentId              INTEGER NOT NULL,
  parentType            TEXT    NOT NULL,      -- enum: task/tool/receipt
  filename              TEXT    NOT NULL,      -- was filePath
  comment               TEXT    NOT NULL,
  last_backup_date      TEXT,                  -- ISO-8601 or NULL
  path_to_cloud_storage TEXT,
  path_version          INTEGER,
  created_date          TEXT    NOT NULL,      -- ISO-8601
  modified_date         TEXT    NOT NULL       -- ISO-8601
);

-- 2) Copy the data across, mapping filePath -> fileName.
INSERT INTO photo_new (
  id,
  parentId,
  parentType,
  filename,
  comment,
  last_backup_date,
  path_to_cloud_storage,
  path_version,
  created_date,
  modified_date
)
SELECT
  id,
  parentId,
  parentType,
  filePath,              -- <- old column becomes new fileName
  comment,
  last_backup_date,
  path_to_cloud_storage,
  path_version,
  created_date,
  modified_date
FROM photo;

-- 3) Drop old table and rename new one.
DROP TABLE photo;
ALTER TABLE photo_new RENAME TO photo;

-- 4) Recreate indexes used by queries.
-- You query frequently by parentId + parentType.
CREATE INDEX IF NOT EXISTS idx_photo_parent
  ON photo(parentId, parentType);

