update check_list_item_type 
set name = 'Labour', description = 'Work to be done'
 where name = 'Action';

ALTER TABLE check_list_item
RENAME COLUMN unit_cost TO estimated_material_cost;

ALTER TABLE check_list_item
RENAME COLUMN effort_in_hours TO estimated_labour;

ALTER TABLE check_list_item
RENAME COLUMN quantity TO estimated_material_quantity;


