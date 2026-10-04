ALTER TABLE trip_settings
ADD COLUMN gps_tracking_enabled INTEGER NOT NULL DEFAULT 0;
ALTER TABLE trip_settings ADD COLUMN active_gps_trip_id INTEGER;

ALTER TABLE trip_log ADD COLUMN distance_source TEXT;
UPDATE trip_log
SET distance_source = 'route'
WHERE distance_metres IS NOT NULL;
