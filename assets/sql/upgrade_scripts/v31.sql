
-- Delete invoice lines with the status 'excluded'
DELETE FROM invoice_line
WHERE status = 'excluded';

