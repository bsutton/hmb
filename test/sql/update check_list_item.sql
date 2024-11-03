update check_list_item
set actual_cost = actual_material_unit_cost * actual_material_quantity / 1000,
    charge = actual_material_unit_cost * actual_material_quantity / 1000
where completed = 1
    and charge = 0
    and actual_material_unit_cost != 0
    and actual_material_unit_cost is not null;
select *
from check_list_item
where description like '%box%';