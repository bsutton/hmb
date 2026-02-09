CREATE TABLE photo_delete_queue_new(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  photo_id INTEGER NOT NULL,
  createdDate TEXT NOT NULL,
  modifiedDate TEXT NOT NULL,
  UNIQUE(photo_id)
);

INSERT INTO photo_delete_queue_new (photo_id, createdDate, modifiedDate)
SELECT
  photo_id,
  strftime('%Y-%m-%dT%H:%M:%f', requested_at / 1000, 'unixepoch'),
  strftime('%Y-%m-%dT%H:%M:%f', requested_at / 1000, 'unixepoch')
FROM photo_delete_queue;

DROP TABLE photo_delete_queue;
ALTER TABLE photo_delete_queue_new RENAME TO photo_delete_queue;
