CREATE TABLE trip_settings (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  enabled INTEGER NOT NULL DEFAULT 0,
  route_lookup_enabled INTEGER NOT NULL DEFAULT 0,
  home_latitude REAL,
  home_longitude REAL,
  home_label TEXT NOT NULL DEFAULT 'Home',
  rate_cents_per_km INTEGER NOT NULL DEFAULT 0 CHECK (rate_cents_per_km >= 0)
);
INSERT INTO trip_settings (id) VALUES (1);
CREATE TABLE trip_observation (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  latitude REAL NOT NULL, longitude REAL NOT NULL,
  observed_at TEXT NOT NULL
);
CREATE TABLE trip_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  departed_at TEXT,
  arrived_at TEXT NOT NULL,
  from_latitude REAL NOT NULL, from_longitude REAL NOT NULL,
  to_latitude REAL NOT NULL, to_longitude REAL NOT NULL,
  from_home INTEGER NOT NULL DEFAULT 0,
  distance_metres INTEGER,
  duration_seconds INTEGER,
  site_id INTEGER REFERENCES site(id) ON DELETE SET NULL,
  job_id INTEGER REFERENCES job(id) ON DELETE SET NULL,
  purpose TEXT NOT NULL DEFAULT '',
  business INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX trip_log_arrived_idx ON trip_log(arrived_at);
