-- Create new table without charge_set
CREATE TABLE task_item_new (
  id INTEGER PRIMARY KEY,
  created_date TEXT NOT NULL,
  modified_date TEXT NOT NULL,
  task_id INTEGER NOT NULL,
  description TEXT NOT NULL,
  item_type_id INTEGER NOT NULL,
  estimated_material_unit_cost INTEGER,
  estimated_material_quantity INTEGER,
  estimated_labour_hours INTEGER,
  estimated_labour_cost INTEGER,
  margin INTEGER NOT NULL,
  charge INTEGER,
  charge_mode TEXT NOT NULL,
  completed INTEGER NOT NULL,
  billed INTEGER NOT NULL,
  invoice_line_id INTEGER,
  measurement_type TEXT,
  dimension1 INTEGER,
  dimension2 INTEGER,
  dimension3 INTEGER,
  units TEXT,
  url TEXT,
  purpose TEXT,
  supplier_id INTEGER,
  labour_entry_mode TEXT NOT NULL,
  actual_material_unit_cost INTEGER,
  actual_material_quantity INTEGER,
  actual_cost INTEGER,
  source_task_item_id INTEGER,
  is_return INTEGER NOT NULL
);

-- Copy data over
INSERT INTO task_item_new (
  id, created_date, modified_date, task_id, description, item_type_id,
  estimated_material_unit_cost, estimated_material_quantity,
  estimated_labour_hours, estimated_labour_cost, margin, charge,
  charge_mode, completed, billed, invoice_line_id, measurement_type,
  dimension1, dimension2, dimension3, units, url, purpose, supplier_id,
  labour_entry_mode, actual_material_unit_cost, actual_material_quantity,
  actual_cost, source_task_item_id, is_return
)
SELECT
  id, created_date, modified_date, task_id, description, item_type_id,
  estimated_material_unit_cost, estimated_material_quantity,
  estimated_labour_hours, estimated_labour_cost, 
    COALESCE(margin, 0) AS margin, charge,
  CASE WHEN charge_set = 1 THEN 'userDefined' ELSE 'calculated' END,
  completed, billed, invoice_line_id, measurement_type,
  dimension1, dimension2, dimension3, units, url, purpose, supplier_id,
  labour_entry_mode, actual_material_unit_cost, actual_material_quantity,
  actual_cost, source_task_item_id, is_return
FROM task_item;

-- Swap tables
DROP TABLE task_item;
ALTER TABLE task_item_new RENAME TO task_item;
