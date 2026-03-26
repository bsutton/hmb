CREATE TABLE IF NOT EXISTS plaster_room_constraint (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  room_id INTEGER NOT NULL REFERENCES plaster_room(id) ON DELETE CASCADE,
  line_id INTEGER NOT NULL REFERENCES plaster_room_line(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  target_value INTEGER,
  created_date TEXT NOT NULL,
  modified_date TEXT NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS plaster_room_constraint_room_line_type_idx
ON plaster_room_constraint(room_id, line_id, type);

CREATE INDEX IF NOT EXISTS plaster_room_constraint_room_idx
ON plaster_room_constraint(room_id, line_id, id);
