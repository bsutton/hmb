CREATE TABLE custom_label_layout (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  unit_system TEXT NOT NULL,
  page_width REAL NOT NULL,
  page_height REAL NOT NULL,
  columns INTEGER NOT NULL,
  rows INTEGER NOT NULL,
  label_width REAL NOT NULL,
  label_height REAL NOT NULL,
  margin_left REAL NOT NULL,
  margin_top REAL NOT NULL,
  gap_x REAL NOT NULL,
  gap_y REAL NOT NULL,
  createdDate TEXT NOT NULL,
  modifiedDate TEXT NOT NULL
);

CREATE UNIQUE INDEX custom_label_layout_name_unq
ON custom_label_layout(name, unit_system);
