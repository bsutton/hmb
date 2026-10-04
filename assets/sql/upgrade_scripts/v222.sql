ALTER TABLE trip_settings ADD COLUMN origin_type TEXT NOT NULL DEFAULT 'business';
ALTER TABLE trip_settings ADD COLUMN alternate_origin_address TEXT NOT NULL DEFAULT '';
UPDATE trip_settings
SET origin_type = 'alternate'
WHERE home_latitude IS NOT NULL AND home_longitude IS NOT NULL;

-- Preserve every trip while allowing a configured address to be its origin.
CREATE TABLE trip_log_v222 (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  departed_at TEXT,
  arrived_at TEXT NOT NULL,
  from_latitude REAL,
  from_longitude REAL,
  from_address TEXT,
  to_latitude REAL NOT NULL,
  to_longitude REAL NOT NULL,
  from_home INTEGER NOT NULL DEFAULT 0,
  distance_metres INTEGER,
  duration_seconds INTEGER,
  site_id INTEGER REFERENCES site(id) ON DELETE SET NULL,
  job_id INTEGER REFERENCES job(id) ON DELETE SET NULL,
  purpose TEXT NOT NULL DEFAULT '',
  business INTEGER NOT NULL DEFAULT 0,
  classified INTEGER NOT NULL DEFAULT 0
);
INSERT INTO trip_log_v222 (
  id, departed_at, arrived_at, from_latitude, from_longitude,
  to_latitude, to_longitude, from_home, distance_metres, duration_seconds,
  site_id, job_id, purpose, business, classified
)
SELECT
  id, departed_at, arrived_at, from_latitude, from_longitude,
  to_latitude, to_longitude, from_home, distance_metres, duration_seconds,
  site_id, job_id, purpose, business,
  CASE WHEN business = 1 OR length(trim(purpose)) > 0 THEN 1 ELSE 0 END
FROM trip_log;
DROP TABLE trip_log;
ALTER TABLE trip_log_v222 RENAME TO trip_log;
CREATE INDEX trip_log_arrived_idx ON trip_log(arrived_at);
