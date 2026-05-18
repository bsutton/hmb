ALTER TABLE supplier
ADD COLUMN lastAccessed TEXT;

CREATE INDEX IF NOT EXISTS supplier_last_accessed_idx
  ON supplier(lastAccessed);
