-- Rename the existing table
ALTER TABLE check_list_item RENAME TO check_list_item_old;

-- Create the new table with `charge` set as NULLABLE
CREATE TABLE check_list_item (
    id INTEGER PRIMARY KEY NOT NULL,
    check_list_id INTEGER NOT NULL,
    description TEXT NOT NULL,
    item_type_id INTEGER NOT NULL,
    estimated_material_unit_cost INTEGER,
    estimated_material_quantity INTEGER,
    estimated_labour_hours INTEGER,
    estimated_labour_cost INTEGER,
    charge INTEGER, 
    margin INTEGER,
    completed INTEGER NOT NULL,
    billed INTEGER NOT NULL,
    invoice_line_id INTEGER,
    measurement_type TEXT,
    dimension1 INTEGER,
    dimension2 INTEGER,
    dimension3 INTEGER,
    units TEXT,
    url TEXT,
    supplier_id INTEGER,
    created_date TEXT NOT NULL,
    modified_date TEXT NOT NULL,
    labour_entry_mode TEXT NOT NULL
);

-- Copy data from the old table to the new table
INSERT INTO check_list_item (
    id,
    check_list_id,
    description,
    item_type_id,
    estimated_material_unit_cost,
    estimated_material_quantity,
    estimated_labour_hours,
    estimated_labour_cost,
    charge,
    margin,
    completed,
    billed,
    invoice_line_id,
    measurement_type,
    dimension1,
    dimension2,
    dimension3,
    units,
    url,
    supplier_id,
    created_date,
    modified_date,
    labour_entry_mode
)
SELECT
    id,
    check_list_id,
    description,
    item_type_id,
    estimated_material_unit_cost,
    estimated_material_quantity,
    estimated_labour_hours,
    estimated_labour_cost,
    charge,
    margin,
    completed,
    billed,
    invoice_line_id,
    measurement_type,
    dimension1,
    dimension2,
    dimension3,
    units,
    url,
    supplier_id,
    createdDate,
    modifiedDate,
    labour_entry_mode
FROM check_list_item_old;

-- Drop the old table
DROP TABLE check_list_item_old;

