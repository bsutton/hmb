-- Add nullable invoice line account code with default '200' which is 
-- the 'Sales' account for the default xero config.
ALTER TABLE system
ADD COLUMN invoice_line_account_code TEXT DEFAULT '200';
-- Add nullable invoice line item code with default '200'
ALTER TABLE system
ADD COLUMN invoice_line_item_code TEXT DEFAULT 'Sales';