
-- 1) Add the nullable column
ALTER TABLE quote
  ADD COLUMN billing_contact_id INTEGER;
