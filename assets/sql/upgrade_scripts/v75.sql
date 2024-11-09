-- rename category to categoryId
-- Step 1: Rename existing tool table
ALTER TABLE tool RENAME TO tool_old;

-- Step 2: Create new tool table with categoryId instead of category
CREATE TABLE tool (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  categoryId INTEGER,
  supplierId INTEGER,
  manufacturerId INTEGER,
  datePurchased TEXT,
  serialNumber TEXT,
  receiptPhotoPath TEXT,
  serialNumberPhotoPath TEXT,
  warrantyPeriod INTEGER,
  cost INTEGER,
  description TEXT,
  createdDate TEXT NOT NULL,
  modifiedDate TEXT NOT NULL,
  FOREIGN KEY (categoryId) REFERENCES category(id),
  FOREIGN KEY (supplierId) REFERENCES supplier(id),
  FOREIGN KEY (manufacturerId) REFERENCES manufacturer(id)
);

-- Step 3: Copy data from old table to new table
INSERT INTO tool (id, name, categoryId, supplierId, manufacturerId, datePurchased, serialNumber, receiptPhotoPath, serialNumberPhotoPath, warrantyPeriod, cost, description, createdDate, modifiedDate)
SELECT id, name, category AS categoryId, supplierId, manufacturerId, datePurchased, serialNumber, receiptPhotoPath, serialNumberPhotoPath, warrantyPeriod, cost, description, createdDate, modifiedDate
FROM tool_old;

-- Step 4: Drop the old table
DROP TABLE tool_old;
