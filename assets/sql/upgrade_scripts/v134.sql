-- Add second alternate email to contact
ALTER TABLE contact ADD COLUMN alternateEmail TEXT;

-- Add boolean (as INTEGER 0/1) for rich-text migration status
ALTER TABLE system ADD COLUMN rich_text_removed INTEGER NOT NULL DEFAULT 0;

