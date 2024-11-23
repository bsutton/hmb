-- Create the new `task_item` table
CREATE TABLE task_item (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id INTEGER NOT NULL,
    description TEXT NOT NULL,
    item_type_id INTEGER NOT NULL,
    estimated_material_unit_cost INTEGER,
    estimated_material_quantity INTEGER,
    estimated_labour_hours INTEGER,
    estimated_labour_cost INTEGER,
    charge INTEGER,
    margin INTEGER,
    completed INTEGER NOT NULL DEFAULT 0,
    billed INTEGER NOT NULL DEFAULT 0,
    invoice_line_id INTEGER,
    measurement_type TEXT,
    dimension1 INTEGER,
    dimension2 INTEGER,
    dimension3 INTEGER,
    units TEXT,
    url TEXT,
    supplier_id INTEGER,
    labour_entry_mode TEXT not null,
    actual_material_unit_cost INTEGER,
    actual_material_quantity INTEGER,
    actual_cost INTEGER,
    created_date TEXT NOT NULL,
    modified_date TEXT NOT NULL,
    FOREIGN KEY (task_id) REFERENCES task(id)
);
-- Populate the `task_item` table
INSERT INTO task_item (
        id,
        task_id,
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
        labour_entry_mode,
        actual_material_unit_cost,
        actual_material_quantity,
        actual_cost,
        created_date,
        modified_date
    )
SELECT check_list_item.id,
    task_check_list.task_id,
    check_list_item.description,
    check_list_item.item_type_id,
    check_list_item.estimated_material_unit_cost,
    check_list_item.estimated_material_quantity,
    check_list_item.estimated_labour_hours,
    check_list_item.estimated_labour_cost,
    check_list_item.charge,
    check_list_item.margin,
    check_list_item.completed,
    check_list_item.billed,
    check_list_item.invoice_line_id,
    check_list_item.measurement_type,
    check_list_item.dimension1,
    check_list_item.dimension2,
    check_list_item.dimension3,
    check_list_item.units,
    check_list_item.url,
    check_list_item.supplier_id,
    check_list_item.labour_entry_mode,
    check_list_item.actual_material_unit_cost,
    check_list_item.actual_material_quantity,
    check_list_item.actual_cost,
    check_list_item.created_date,
    check_list_item.modified_date
FROM check_list_item
    JOIN task_check_list ON check_list_item.check_list_id = task_check_list.check_list_id;
-- Drop the old `task_checklist` table
DROP TABLE task_check_list;
-- 1. Create the new table `task_item_type` with all columns from `check_list_item_type`
CREATE TABLE task_item_type (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    description TEXT,
    to_purchase INTEGER NOT NULL DEFAULT 0,
    -- Assuming 0 as the default for a boolean-like column
    color_code TEXT,
    created_date TEXT NOT NULL,
    modified_date TEXT NOT NULL
);
-- 2. Copy data from the old table `check_list_item_type` to the new table `task_item_type`
INSERT INTO task_item_type (
        id,
        name,
        description,
        to_purchase,
        color_code,
        created_date,
        modified_date
    )
SELECT id,
    name,
    description,
    to_purchase,
    color_code,
    createdDate,
    modifiedDate
FROM check_list_item_type;
-- 3. Delete old check list items and check lists.
delete from check_list_item_type;
delete from check_list;