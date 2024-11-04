ALTER TABLE system ADD COLUMN logo_aspect_ratio VARCHAR(255);

UPDATE system SET logo_aspect_ratio = logo_type;

