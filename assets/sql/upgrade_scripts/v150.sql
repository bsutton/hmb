ALTER TABLE job
  ADD COLUMN is_stock INTEGER NOT NULL DEFAULT 0;

-- Ensure a dedicated Stock customer exists.
INSERT INTO customer (
    name,
    description,
    disbarred,
    customerType,
    default_hourly_rate,
    createdDate,
    modifiedDate
  )
SELECT 'Stock',
  'System customer for stock management',
  0,
  0,
  0,
  datetime('now'),
  datetime('now')
WHERE NOT EXISTS (
    SELECT 1
    FROM customer
    WHERE lower(name) = 'stock'
  );

-- Mark an existing Stock job as the stock job, or create one if missing.
INSERT INTO job (
    customer_id,
    summary,
    description,
    site_id,
    contact_id,
    status_id,
    hourly_rate,
    booking_fee,
    last_active,
    billing_type,
    booking_fee_invoiced,
    created_date,
    modified_date,
    assumption,
    internal_notes,
    billing_contact_id,
    is_stock
  )
SELECT (
    SELECT c.id
    FROM customer c
    WHERE lower(c.name) = 'stock'
    LIMIT 1
  ),
  'Stock',
  'System stock job',
  NULL,
  NULL,
  'InProgress',
  0,
  0,
  0,
  'nonBillable',
  0,
  datetime('now'),
  datetime('now'),
  '',
  '',
  NULL,
  1
WHERE NOT EXISTS (
    SELECT 1
    FROM job
    WHERE is_stock = 1
       OR lower(summary) = 'stock'
  );

UPDATE job
SET is_stock = 1
WHERE id = (
    SELECT id
    FROM job
    WHERE is_stock = 1
       OR lower(summary) = 'stock'
    ORDER BY is_stock DESC,
      id ASC
    LIMIT 1
  );

UPDATE job
SET billing_type = 'nonBillable'
WHERE is_stock = 1;

-- Ensure a Stock task exists for the stock job.
INSERT INTO task (
    job_id,
    name,
    description,
    task_status_id,
    createdDate,
    modifiedDate,
    billing_type,
    assumption,
    internal_notes
  )
SELECT j.id,
  'Stock',
  'System stock task',
  2,
  datetime('now'),
  datetime('now'),
  'nonBillable',
  '',
  ''
FROM job j
WHERE j.is_stock = 1
  AND NOT EXISTS (
    SELECT 1
    FROM task t
    WHERE t.job_id = j.id
      AND lower(t.name) = 'stock'
  );
