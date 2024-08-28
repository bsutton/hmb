ALTER TABLE system ADD COLUMN logo_aspect_ratio VARCHAR(255);

UPDATE system SET logo_aspect_ratio = logo_type;

ALTER TABLE system DROP COLUMN logo_type;
