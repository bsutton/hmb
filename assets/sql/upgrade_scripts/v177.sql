CREATE TABLE IF NOT EXISTS receipt_task_item (
  receipt_id INTEGER NOT NULL,
  task_item_id INTEGER NOT NULL,
  created_date TEXT NOT NULL DEFAULT (datetime('now')),
  modified_date TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (receipt_id, task_item_id),
  FOREIGN KEY (receipt_id) REFERENCES receipt(id),
  FOREIGN KEY (task_item_id) REFERENCES task_item(id)
);

CREATE INDEX IF NOT EXISTS idx_receipt_task_item_task_item_id
  ON receipt_task_item(task_item_id);
