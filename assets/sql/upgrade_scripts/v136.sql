-- Task estimate catalog
CREATE TABLE IF NOT EXISTS task_estimate (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  summary TEXT DEFAULT '',
  description TEXT DEFAULT '',
  assumption TEXT DEFAULT '',
  inclusions TEXT DEFAULT '',
  exclusions TEXT DEFAULT '',
  tags TEXT DEFAULT '',
  active INTEGER NOT NULL DEFAULT 1,

  item_type_id INTEGER NOT NULL,             -- FK -> task_item_type.id
  labour_entry_mode TEXT NOT NULL,           -- 'Hours' | 'Dollars'

  estimated_labour_hours INTEGER,            -- Fixed(3dp) minor units
  estimated_labour_cost INTEGER,             -- Money(2dp) minor units
  estimated_material_unit_cost INTEGER,      -- Money(2dp) minor units
  estimated_material_quantity INTEGER,       -- Fixed(3dp) minor units
  margin INTEGER NOT NULL DEFAULT 0,         -- Percentage(3dp) minor units

  url TEXT DEFAULT '',
  measurement_type TEXT,
  dimension1 INTEGER NOT NULL DEFAULT 0,     -- Fixed(3dp)
  dimension2 INTEGER NOT NULL DEFAULT 0,     -- Fixed(3dp)
  dimension3 INTEGER NOT NULL DEFAULT 0,     -- Fixed(3dp)
  units TEXT,

  supplier_id INTEGER,
  preferred_billing_type TEXT,               -- enum name from BillingType
  suggested_charge INTEGER,                  -- Money(2dp)

  created_date TEXT NOT NULL,
  modified_date TEXT NOT NULL
);

-- Search & filtering
CREATE INDEX IF NOT EXISTS idx_task_estimate_active
  ON task_estimate(active);

CREATE INDEX IF NOT EXISTS idx_task_estimate_name
  ON task_estimate(name);

CREATE INDEX IF NOT EXISTS idx_task_estimate_item_type
  ON task_estimate(item_type_id);

-- Optional: lightweight full-text search via LIKE (keep name short)
-- Consider FTS5 in a future migration if you want proper search.

