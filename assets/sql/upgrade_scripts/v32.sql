
-- Delete invoice lines with the status 'excluded'
DELETE FROM invoice_line
WHERE status = 2;

update invoice_line set status = 2 where status = 3;

