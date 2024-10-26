ALTER TABLE check_list_item
ADD COLUMN actual_material_unit_cost INTEGER;
ALTER TABLE check_list_item
ADD COLUMN actual_material_quantity INTEGER;
ALTER TABLE check_list_item
ADD COLUMN actual_cost INTEGER;
UPDATE check_list_item
SET actual_material_unit_cost = estimated_material_unit_cost,
    actual_material_quantity = estimated_material_quantity
WHERE completed = 1
    AND item_type_id = 1;