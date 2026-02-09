ALTER TABLE system ADD COLUMN ihserver_url TEXT;
ALTER TABLE system ADD COLUMN ihserver_token TEXT;
ALTER TABLE system ADD COLUMN enable_ihserver_integration INTEGER NOT NULL DEFAULT 0;
ALTER TABLE system ADD COLUMN openai_api_key TEXT;

CREATE TABLE booking_request(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    remote_id TEXT NOT NULL UNIQUE,
    status INTEGER NOT NULL DEFAULT 0,
    payload TEXT NOT NULL,
    createdDate TEXT NOT NULL,
    modifiedDate TEXT NOT NULL
);
