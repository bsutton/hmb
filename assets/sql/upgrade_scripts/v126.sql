-- 1) Add the new column (nullable by default)
ALTER TABLE time_entry
ADD COLUMN supplier_id INTEGER REFERENCES supplier(id);
-- 2) (Optional) Speed up lookups by indexing the new column
CREATE INDEX IF NOT EXISTS idx_time_entry_supplier_id ON time_entry(supplier_id);