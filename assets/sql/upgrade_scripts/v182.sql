-- Back-fill actual costs for completed material-style task items that were
-- completed without the shopping completion dialog.

UPDATE task_item
SET
  actual_material_unit_cost = CASE
    WHEN (actual_material_unit_cost IS NULL OR actual_material_unit_cost = 0)
      THEN estimated_material_unit_cost
    ELSE actual_material_unit_cost
  END,
  actual_material_quantity = CASE
    WHEN (actual_material_quantity IS NULL OR actual_material_quantity = 0)
      THEN estimated_material_quantity
    ELSE actual_material_quantity
  END
WHERE completed = 1
  AND invoice_line_id IS NULL
  AND item_type_id != 5
  AND (
    actual_material_unit_cost IS NULL
    OR actual_material_unit_cost = 0
    OR actual_material_quantity IS NULL
    OR actual_material_quantity = 0
  );

UPDATE task_item
SET actual_cost = actual_material_unit_cost * actual_material_quantity / 1000
WHERE completed = 1
  AND invoice_line_id IS NULL
  AND item_type_id != 5
  AND actual_material_unit_cost IS NOT NULL
  AND actual_material_quantity IS NOT NULL
  AND (actual_cost IS NULL OR actual_cost = 0);
