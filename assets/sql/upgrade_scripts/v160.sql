CREATE TABLE quote_task_photo (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  quote_id INTEGER NOT NULL REFERENCES quote(id) ON DELETE CASCADE,
  task_id INTEGER NOT NULL REFERENCES task(id) ON DELETE CASCADE,
  photo_id INTEGER NOT NULL REFERENCES photo(id) ON DELETE CASCADE,
  display_order INTEGER NOT NULL DEFAULT 0,
  comment TEXT NOT NULL DEFAULT '',
  created_date TEXT NOT NULL,
  modified_date TEXT NOT NULL
);

CREATE UNIQUE INDEX quote_task_photo_quote_photo_idx
ON quote_task_photo(quote_id, photo_id);

CREATE INDEX quote_task_photo_quote_task_idx
ON quote_task_photo(quote_id, task_id, display_order);
