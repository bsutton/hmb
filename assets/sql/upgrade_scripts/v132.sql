-- fixed records wth null actuals caused by flawed forUpdate method.
update task_item
set actual_material_unit_cost = estimated_material_unit_cost,
actual_material_quantity = estimated_material_quantity

where actual_material_unit_cost is NULL
and charge is not null
and charge_set = 1
and labour_entry_mode = 'Dollars'
;

