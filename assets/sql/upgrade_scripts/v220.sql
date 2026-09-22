CREATE TABLE paint_room_estimate (
  room_id INTEGER PRIMARY KEY REFERENCES plaster_room(id) ON DELETE CASCADE,
  settings_json TEXT NOT NULL
);
