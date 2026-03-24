CREATE TABLE plaster_project (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  job_id INTEGER NOT NULL REFERENCES job(id) ON DELETE CASCADE,
  task_id INTEGER REFERENCES task(id) ON DELETE SET NULL,
  supplier_id INTEGER REFERENCES supplier(id) ON DELETE SET NULL,
  waste_percent INTEGER NOT NULL DEFAULT 15,
  created_date TEXT NOT NULL,
  modified_date TEXT NOT NULL
);

CREATE INDEX plaster_project_job_idx
ON plaster_project(job_id, modified_date DESC, id DESC);

CREATE TABLE plaster_room (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id INTEGER NOT NULL REFERENCES plaster_project(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  unit_system TEXT NOT NULL,
  ceiling_height INTEGER NOT NULL,
  plaster_ceiling INTEGER NOT NULL DEFAULT 1,
  created_date TEXT NOT NULL,
  modified_date TEXT NOT NULL
);

CREATE TABLE plaster_room_line (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  room_id INTEGER NOT NULL REFERENCES plaster_room(id) ON DELETE CASCADE,
  seq_no INTEGER NOT NULL,
  start_x INTEGER NOT NULL,
  start_y INTEGER NOT NULL,
  length INTEGER NOT NULL,
  plaster_selected INTEGER NOT NULL DEFAULT 1,
  created_date TEXT NOT NULL,
  modified_date TEXT NOT NULL
);

CREATE UNIQUE INDEX plaster_room_line_room_seq_idx
ON plaster_room_line(room_id, seq_no);

CREATE TABLE plaster_room_opening (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  line_id INTEGER NOT NULL REFERENCES plaster_room_line(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  offset_from_start INTEGER NOT NULL,
  width INTEGER NOT NULL,
  height INTEGER NOT NULL,
  sill_height INTEGER NOT NULL DEFAULT 0,
  created_date TEXT NOT NULL,
  modified_date TEXT NOT NULL
);

CREATE TABLE plaster_material_size (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id INTEGER NOT NULL REFERENCES plaster_project(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  unit_system TEXT NOT NULL,
  width INTEGER NOT NULL,
  height INTEGER NOT NULL,
  created_date TEXT NOT NULL,
  modified_date TEXT NOT NULL
);
