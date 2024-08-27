ALTER TABLE system DROP COLUMN logo_type;

ALTER TABLE system ADD COLUMN logo_type TEXT NOT NULL DEFAULT 'square';

