-- Add an assumption column to the quote table:
ALTER TABLE quote
ADD COLUMN assumption TEXT NOT NULL DEFAULT '';
-- Add an assumption column to the quote_line_group table:
ALTER TABLE quote_line_group
ADD COLUMN assumption TEXT NOT NULL DEFAULT '';