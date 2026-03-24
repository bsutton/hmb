CREATE TABLE plaster_material_size_v164 (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  supplier_id INTEGER NOT NULL REFERENCES supplier(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  unit_system TEXT NOT NULL,
  width INTEGER NOT NULL,
  height INTEGER NOT NULL,
  created_date TEXT NOT NULL,
  modified_date TEXT NOT NULL
);

INSERT INTO plaster_material_size_v164 (
  supplier_id,
  name,
  unit_system,
  width,
  height,
  created_date,
  modified_date
)
SELECT DISTINCT
  project.supplier_id,
  material.name,
  material.unit_system,
  material.width,
  material.height,
  material.created_date,
  material.modified_date
FROM plaster_material_size material
JOIN plaster_project project
  ON project.id = material.project_id
WHERE project.supplier_id IS NOT NULL;

DROP TABLE plaster_material_size;

ALTER TABLE plaster_material_size_v164
RENAME TO plaster_material_size;

CREATE INDEX plaster_material_size_supplier_idx
ON plaster_material_size(supplier_id, name, id);
