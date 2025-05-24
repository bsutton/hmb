-- 1) Add new columns to quote_line_group
ALTER TABLE quote_line_group
ADD COLUMN task_id INTEGER;
ALTER TABLE quote_line_group
ADD COLUMN line_approval_status TEXT NOT NULL DEFAULT 'preApproval' CHECK(
    line_approval_status IN ('preApproval', 'approved', 'rejected')
  );
-- 3) Rebuild quote_line without task_id or line_approval_status
ALTER TABLE quote_line
  RENAME TO _quote_line_old;
CREATE TABLE quote_line (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  quote_id INTEGER NOT NULL,
  quote_line_group_id INTEGER,
  description TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  unit_charge INTEGER NOT NULL,
  line_total INTEGER NOT NULL,
  created_date TEXT NOT NULL,
  modified_date TEXT NOT NULL,
  line_chargeable_status TEXT NOT NULL DEFAULT 'normal' CHECK(
    line_chargeable_status IN ('normal', 'noCharge', 'noChargeHidden')
  ),
  FOREIGN KEY (quote_id) REFERENCES quote(id),
  FOREIGN KEY (quote_line_group_id) REFERENCES quote_line_group(id)
);
INSERT INTO quote_line (
    id,
    quote_id,
    quote_line_group_id,
    description,
    quantity,
    unit_charge,
    line_total,
    created_date,
    modified_date,
    line_chargeable_status
  )
SELECT id,
  quote_id,
  quote_line_group_id,
  description,
  quantity,
  unit_charge,
  line_total,
  created_date,
  modified_date,
  line_chargeable_status
FROM _quote_line_old;
DROP TABLE _quote_line_old;