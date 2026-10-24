-- Existing snapshots contain only overpayments.
ALTER TABLE xero_customer_credit
ADD COLUMN credit_kind TEXT NOT NULL DEFAULT 'overpayment'
CHECK (credit_kind IN ('overpayment', 'prepayment', 'credit_note'));
