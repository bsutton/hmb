ALTER TABLE check_list_item RENAME COLUMN estimated_material_cost TO estimated_material_unit_cost;

ALTER TABLE check_list_item RENAME COLUMN estimated_labour TO estimated_labour_hours;

ALTER TABLE check_list_item ADD COLUMN estimated_labour_cost INTEGER;




