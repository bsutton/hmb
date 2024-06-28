ALTER TABLE check_list_item RENAME TO check_list_item_old;

CREATE TABLE check_list_item (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  check_list_id INTEGER NOT NULL,
  description TEXT NOT NULL,
  item_type_id INTEGER NOT NULL,
  unit_cost INTEGER NOT NULL,
  effort_in_hours INTEGER NOT NULL,
  quantity INTEGER NOT NULL,
  completed INTEGER NOT NULL,
  billed INTEGER NOT NULL,
  invoice_line_id INTEGER,
  createdDate TEXT NOT NULL,
  modifiedDate TEXT NOT NULL,
  FOREIGN KEY (check_list_id) REFERENCES check_list(id),
  FOREIGN KEY (invoice_line_id) REFERENCES invoice_line(id)
);


INSERT INTO check_list_item (id, check_list_id, description, item_type_id, unit_cost, effort_in_hours, quantity, completed, billed,  createdDate, modifiedDate)
SELECT id, check_list_id, description, item_type_id, unit_cost, effort_in_hours, quantity, completed, billed,  createdDate, modifiedDate
FROM check_list_item_old;

DROP TABLE check_list_item_old;
