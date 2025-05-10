CREATE TABLE IF NOT EXISTS receipt (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    receipt_date TEXT NOT NULL,
    job_id INTEGER NOT NULL,
    supplier_id INTEGER NOT NULL,
    total_excluding_tax INTEGER NOT NULL,
    tax INTEGER NOT NULL,
    total_including_tax INTEGER NOT NULL,
    created_date TEXT NOT NULL DEFAULT (datetime('now')),  
    modified_date TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY(job_id) REFERENCES job(id),
    FOREIGN KEY(supplier_id) REFERENCES supplier(id)
);
CREATE INDEX IF NOT EXISTS idx_receipt_date ON receipt(receipt_date);
CREATE INDEX IF NOT EXISTS idx_receipt_job_id ON receipt(job_id);
CREATE INDEX IF NOT EXISTS idx_receipt_supplier_id ON receipt(supplier_id);

-- add auth tokens for chat gpt
ALTER TABLE system ADD COLUMN chatgpt_access_token TEXT;
ALTER TABLE system ADD COLUMN chatgpt_refresh_token TEXT;
ALTER TABLE system ADD COLUMN chatgpt_token_expiry TEXT;