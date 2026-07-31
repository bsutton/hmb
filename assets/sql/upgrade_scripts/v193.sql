ALTER TABLE system
ADD COLUMN smtp_provider TEXT NOT NULL DEFAULT 'custom';

ALTER TABLE system
ADD COLUMN smtp_auth_mode TEXT NOT NULL DEFAULT 'password';
