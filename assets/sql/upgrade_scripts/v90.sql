PRAGMA foreign_keys = OFF;
-- 1. Rename the old table
ALTER TABLE Tool
    RENAME TO Tool_old;
-- 2. Create the new Tool table with the desired schema
CREATE TABLE Tool (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    categoryId INTEGER,
    supplierId INTEGER,
    manufacturerId INTEGER,
    datePurchased TEXT,
    serialNumber TEXT,
    warrantyPeriod INTEGER,
    cost INTEGER,
    description TEXT,
    receiptPhotoId INTEGER REFERENCES Photo(id) ON DELETE
    SET NULL,
        serialNumberPhotoId INTEGER REFERENCES Photo(id) ON DELETE
    SET NULL,
        createdDate TEXT NOT NULL,
        modifiedDate TEXT NOT NULL
);
-- 3. Copy data from the old table to the new one
-- Notice we omit the old columns (receiptPhotoPath, serialNumberPhotoPath)
INSERT INTO Tool (
        id,
        name,
        categoryId,
        supplierId,
        manufacturerId,
        datePurchased,
        serialNumber,
        warrantyPeriod,
        cost,
        description,
        createdDate,
        modifiedDate
    )
SELECT id,
    name,
    categoryId,
    supplierId,
    manufacturerId,
    datePurchased,
    serialNumber,
    warrantyPeriod,
    cost,
    description,
    createdDate,
    modifiedDate
FROM Tool_old;
-- 4. Drop the old table
DROP TABLE Tool_old;
PRAGMA foreign_keys = ON;