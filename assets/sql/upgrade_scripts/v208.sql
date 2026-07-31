-- Replace the ambiguous material quantity/cost columns with complete prices.
--
-- Existing rows become individual-item prices. Historical package details
-- were never stored and therefore cannot be reconstructed.
CREATE TABLE task_item_new (
  id INTEGER PRIMARY KEY,
  created_date TEXT NOT NULL,
  modified_date TEXT NOT NULL,
  task_id INTEGER NOT NULL,
  description TEXT NOT NULL,
  item_type_id INTEGER NOT NULL,
  estimated_price_mode TEXT,
  estimated_quantity INTEGER,
  estimated_unit_cost INTEGER,
  estimated_items_per_package INTEGER,
  estimated_labour_hours INTEGER,
  estimated_labour_cost INTEGER,
  margin INTEGER NOT NULL,
  total_line_charge INTEGER,
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
  actual_price_mode TEXT,
  actual_quantity INTEGER,
  actual_unit_cost INTEGER,
  actual_items_per_package INTEGER,
  source_task_item_id INTEGER,
  is_return INTEGER NOT NULL,
  CHECK (
    estimated_price_mode IS NULL
    OR estimated_price_mode IN ('items', 'packages')
  ),
  CHECK (
    (
      estimated_price_mode IS NULL
      AND estimated_quantity IS NULL
      AND estimated_unit_cost IS NULL
      AND estimated_items_per_package IS NULL
    )
    OR (
      estimated_price_mode = 'items'
      AND estimated_quantity IS NOT NULL
      AND estimated_unit_cost IS NOT NULL
      AND estimated_items_per_package IS NULL
    )
    OR (
      estimated_price_mode = 'packages'
      AND estimated_quantity IS NOT NULL
      AND estimated_quantity > 0
      AND estimated_quantity % 1000 = 0
      AND estimated_unit_cost IS NOT NULL
      AND estimated_items_per_package > 0
      AND estimated_items_per_package % 1000 = 0
    )
  ),
  CHECK (
    actual_price_mode IS NULL
    OR actual_price_mode IN ('items', 'packages')
  ),
  CHECK (
    (
      actual_price_mode IS NULL
      AND actual_quantity IS NULL
      AND actual_unit_cost IS NULL
      AND actual_items_per_package IS NULL
    )
    OR (
      actual_price_mode = 'items'
      AND actual_quantity IS NOT NULL
      AND actual_unit_cost IS NOT NULL
      AND actual_items_per_package IS NULL
    )
    OR (
      actual_price_mode = 'packages'
      AND actual_quantity IS NOT NULL
      AND actual_quantity > 0
      AND actual_quantity % 1000 = 0
      AND actual_unit_cost IS NOT NULL
      AND actual_items_per_package > 0
      AND actual_items_per_package % 1000 = 0
    )
  ),
  CHECK (
    estimated_price_mode != 'packages'
    OR estimated_items_per_package > 0
  ),
  CHECK (
    actual_price_mode != 'packages'
    OR actual_items_per_package > 0
  )
);

INSERT INTO task_item_new (
  id,
  created_date,
  modified_date,
  task_id,
  description,
  item_type_id,
  estimated_price_mode,
  estimated_quantity,
  estimated_unit_cost,
  estimated_items_per_package,
  estimated_labour_hours,
  estimated_labour_cost,
  margin,
  total_line_charge,
  charge_mode,
  completed,
  billed,
  invoice_line_id,
  measurement_type,
  dimension1,
  dimension2,
  dimension3,
  units,
  url,
  purpose,
  supplier_id,
  labour_entry_mode,
  actual_price_mode,
  actual_quantity,
  actual_unit_cost,
  actual_items_per_package,
  source_task_item_id,
  is_return
)
SELECT
  id,
  created_date,
  modified_date,
  task_id,
  description,
  item_type_id,
  CASE
    WHEN estimated_material_quantity IS NOT NULL
      AND estimated_material_unit_cost IS NOT NULL
    THEN 'items'
  END,
  CASE
    WHEN estimated_material_quantity IS NOT NULL
      AND estimated_material_unit_cost IS NOT NULL
    THEN estimated_material_quantity
  END,
  CASE
    WHEN estimated_material_quantity IS NOT NULL
      AND estimated_material_unit_cost IS NOT NULL
    THEN estimated_material_unit_cost
  END,
  NULL,
  estimated_labour_hours,
  estimated_labour_cost,
  margin,
  total_line_charge,
  charge_mode,
  completed,
  billed,
  invoice_line_id,
  measurement_type,
  dimension1,
  dimension2,
  dimension3,
  units,
  url,
  purpose,
  supplier_id,
  labour_entry_mode,
  CASE
    WHEN actual_material_quantity IS NOT NULL
      AND actual_material_unit_cost IS NOT NULL
    THEN 'items'
  END,
  CASE
    WHEN actual_material_quantity IS NOT NULL
      AND actual_material_unit_cost IS NOT NULL
    THEN actual_material_quantity
  END,
  CASE
    WHEN actual_material_quantity IS NOT NULL
      AND actual_material_unit_cost IS NOT NULL
    THEN actual_material_unit_cost
  END,
  NULL,
  source_task_item_id,
  is_return
FROM task_item;

DROP TABLE task_item;

ALTER TABLE task_item_new RENAME TO task_item;
