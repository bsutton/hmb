CREATE TABLE IF NOT EXISTS receipt_line_item (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  receipt_id INTEGER NOT NULL,
  description TEXT NOT NULL,
  quantity REAL NOT NULL DEFAULT 1,
  unit_price INTEGER NOT NULL DEFAULT 0,
  line_total_ex_tax INTEGER NOT NULL DEFAULT 0,
  tax_amount INTEGER NOT NULL DEFAULT 0,
  line_total_inc_tax INTEGER NOT NULL DEFAULT 0,
  matched_task_item_id INTEGER,
  confidence INTEGER NOT NULL DEFAULT 0,
  source TEXT NOT NULL DEFAULT 'manual',
  created_date TEXT NOT NULL DEFAULT (datetime('now')),
  modified_date TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY(receipt_id) REFERENCES receipt(id),
  FOREIGN KEY(matched_task_item_id) REFERENCES task_item(id)
);

CREATE INDEX IF NOT EXISTS receipt_line_item_receipt_idx
  ON receipt_line_item(receipt_id);

CREATE INDEX IF NOT EXISTS receipt_line_item_task_item_idx
  ON receipt_line_item(matched_task_item_id);
