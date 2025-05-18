-- Migration: add task_id + rename unit_price → unit_charge + switch status→enums

-- 1) Rename the old table
ALTER TABLE quote_line RENAME TO quote_line_old;

-- 2) Create the new table with the added task_id column
CREATE TABLE quote_line (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  quote_id INTEGER NOT NULL,
  quote_line_group_id INTEGER,
  task_id INTEGER,                                -- ← new
  description TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  unit_charge INTEGER NOT NULL,                   -- ← renamed
  line_total INTEGER NOT NULL,
  created_date TEXT NOT NULL,
  modified_date TEXT NOT NULL,

  line_chargeable_status TEXT NOT NULL DEFAULT 'none'
    CHECK(line_chargeable_status IN ('none','included','excluded')),

  line_approval_status TEXT NOT NULL DEFAULT 'preApproval'
    CHECK(line_approval_status IN ('preApproval','approved','rejected')),

  FOREIGN KEY (quote_id) REFERENCES quote(id),
  FOREIGN KEY (quote_line_group_id) REFERENCES quote_line_group(id),
  FOREIGN KEY (task_id) REFERENCES task(id)       -- ← FK to task
);

-- 3) Copy & transform existing data
INSERT INTO quote_line (
  id,
  quote_id,
  quote_line_group_id,
  task_id,                                       -- ← new (no existing data → NULL)
  description,
  quantity,
  unit_charge,
  line_total,
  created_date,
  modified_date,
  line_chargeable_status,
  line_approval_status
)
SELECT
  id,
  quote_id,
  quote_line_group_id,
  NULL AS task_id,                               -- ← default to NULL
  description,
  quantity,
  unit_price AS unit_charge,                     -- ← map old → new
  line_total,
  created_date,
  modified_date,
  CASE status                                    -- map old integer status → enum
    WHEN 0 THEN 'normal'
    WHEN 1 THEN 'noCharge'
    WHEN 2 THEN 'noChargeHidden'
    ELSE 'normal'
  END,
  'preApproval'                                  -- default for new approval status
FROM quote_line_old;

-- 4) Drop the old table
DROP TABLE quote_line_old;




-- Set quote line status to 'approved' where quote is approved or invoiced
UPDATE quote_line
SET line_approval_status = 'approved'
WHERE quote_id IN (
  SELECT id FROM quote
  WHERE state IN ('approved', 'invoiced')
);

-- Set to 'preApproval' where quote is reviewing or sent
UPDATE quote_line
SET line_approval_status = 'preApproval'
WHERE quote_id IN (
  SELECT id FROM quote
  WHERE state IN ('reviewing', 'sent')
);
