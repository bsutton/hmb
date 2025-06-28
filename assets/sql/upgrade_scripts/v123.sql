-- Add nullable invoice line account code with default 'Sales'
ALTER TABLE system
ADD COLUMN invoice_line_account_code TEXT DEFAULT 'Sales';
-- Add nullable invoice line item code with default '200'
ALTER TABLE system
ADD COLUMN invoice_line_item_code TEXT DEFAULT '200';