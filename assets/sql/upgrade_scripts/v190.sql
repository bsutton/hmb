PRAGMA foreign_keys=off;

CREATE TABLE receipt_v190 (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    receipt_date TEXT NOT NULL,
    job_id INTEGER,
    supplier_id INTEGER NOT NULL,
    total_excluding_tax INTEGER NOT NULL,
    tax INTEGER NOT NULL,
    total_including_tax INTEGER NOT NULL,
    created_date TEXT NOT NULL DEFAULT (datetime('now')),
    modified_date TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY(job_id) REFERENCES job(id),
    FOREIGN KEY(supplier_id) REFERENCES supplier(id)
);

INSERT INTO receipt_v190 (
  id,
  receipt_date,
  job_id,
  supplier_id,
  total_excluding_tax,
  tax,
  total_including_tax,
  created_date,
  modified_date
)
SELECT
  id,
  receipt_date,
  job_id,
  supplier_id,
  total_excluding_tax,
  tax,
  total_including_tax,
  created_date,
  modified_date
FROM receipt;

DROP TABLE receipt;

ALTER TABLE receipt_v190
RENAME TO receipt;

CREATE INDEX IF NOT EXISTS idx_receipt_date ON receipt(receipt_date);
CREATE INDEX IF NOT EXISTS idx_receipt_job_id ON receipt(job_id);
CREATE INDEX IF NOT EXISTS idx_receipt_supplier_id ON receipt(supplier_id);

ALTER TABLE receipt_line_item
ADD COLUMN expense_category TEXT NOT NULL DEFAULT 'materials';

CREATE INDEX IF NOT EXISTS receipt_line_item_expense_category_idx
  ON receipt_line_item(expense_category);

PRAGMA foreign_keys=on;
