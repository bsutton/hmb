-- Step 1: Create a new table with the additional fields
CREATE TABLE tool_new (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    datePurchased TEXT,
    supplierId INTEGER,
    manufacturerId INTEGER,
    receiptPhotoPath TEXT,
    serialNumberPhotoPath TEXT,
    serialNumber TEXT,
    warrantyPeriod INTEGER,
    cost int,
    description TEXT,
    createdDate TEXT,
    modifiedDate TEXT,
    FOREIGN KEY (supplierId) REFERENCES Supplier(id),
    FOREIGN KEY (manufacturerId) REFERENCES Manufacturer(id)
);
-- Step 2: Copy data from the old table to the new table
INSERT INTO tool_new (
        id,
        name,
        category,
        datePurchased,
        serialNumber,
        supplierId,
        createdDate,
        modifiedDate
    )
SELECT id,
    name,
    category,
    datePurchased,
    serialNumber,
    supplierId,
    createdDate,
    modifiedDate
FROM tool;
-- Step 3: Drop the old table
DROP TABLE tool;
-- Step 4: Rename the new table to the original table name
ALTER TABLE tool_new
    RENAME TO tool;
-- manfacturer table    
CREATE TABLE manufacturer (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    description TEXT,
    contactNumber TEXT,
    email TEXT,
    address TEXT,
    createdDate TEXT,
    modifiedDate TEXT
);