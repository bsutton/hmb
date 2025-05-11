PRAGMA foreign_keys=off;

-- 1. Rename the old table
ALTER TABLE task_item RENAME TO task_item_old;

-- 2. Re-create with the new schema
CREATE TABLE task_item (
  id                           INTEGER PRIMARY KEY,
  created_date                 TEXT    NOT NULL,
  modified_date                TEXT    NOT NULL,
  task_id                      INTEGER NOT NULL,
  description                  TEXT    NOT NULL,
  item_type_id                 INTEGER NOT NULL,
  estimated_material_unit_cost INTEGER,
  estimated_material_quantity  INTEGER,
  estimated_labour_hours       INTEGER,
  estimated_labour_cost        INTEGER,
  charge                       INTEGER,
  charge_set                   INTEGER NOT NULL,
  margin                       INTEGER NOT NULL,
  completed                    INTEGER NOT NULL,
  billed                       INTEGER NOT NULL,
  measurement_type             TEXT,
  dimension1                   INTEGER NOT NULL,
  dimension2                   INTEGER NOT NULL,
  dimension3                   INTEGER NOT NULL,
  units                        TEXT,
  url                          TEXT    NOT NULL,
  labour_entry_mode            TEXT    NOT NULL,
  invoice_line_id              INTEGER,
  supplier_id                  INTEGER,
  actual_material_unit_cost    INTEGER,
  actual_material_quantity     INTEGER,
  actual_cost                  INTEGER,
  -- ✚ new return linkage
  source_task_item_id          INTEGER REFERENCES task_item(id),
  is_return                    INTEGER NOT NULL DEFAULT 0
);

-- 3. Copy data across
INSERT INTO task_item (
  id, task_id, description, item_type_id,
  estimated_material_unit_cost, estimated_material_quantity,
  estimated_labour_hours, estimated_labour_cost,
  margin, charge, charge_set, completed,
  billed, invoice_line_id, measurement_type,
  dimension1, dimension2, dimension3, units, url,
  supplier_id, labour_entry_mode, actual_material_unit_cost,
  actual_material_quantity, actual_cost,
  -- map old 'returned' flag into is_return, clear source_task_item_id
  source_task_item_id, is_return,
  created_date, modified_date
)
SELECT
  id, task_id, description, item_type_id,
  estimated_material_unit_cost, estimated_material_quantity,
  estimated_labour_hours, estimated_labour_cost,
  margin, charge, charge_set, completed,
  billed, invoice_line_id, measurement_type,
  dimension1, dimension2, dimension3, units, url,
  supplier_id, labour_entry_mode, actual_material_unit_cost,
  actual_material_quantity, actual_cost,
  NULL AS source_task_item_id,
  CASE WHEN returned = 1 THEN 1 ELSE 0 END AS is_return,
  created_date, modified_date
FROM task_item_old;

-- 4. Drop the old table
DROP TABLE task_item_old;

-- 5. (Optional) Ensure an original item can only be returned once
CREATE UNIQUE INDEX IF NOT EXISTS
  idx_task_item_unique_return
ON task_item(source_task_item_id)
WHERE source_task_item_id IS NOT NULL;

PRAGMA foreign_keys=on;
