-- SMS templates should address the selected/default contact rather than the
-- customer entity.
UPDATE message_template
SET message = REPLACE(message, '{{customer.name}}', '{{contact.name}}')
WHERE message_type = 'sms'
  AND message LIKE '%{{customer.name}}%';

-- Keep Blank as a lightweight free-form starter with an insertion point and
-- the signature separated by a blank line.
UPDATE message_template
SET message = CHAR(10) || CHAR(10) || '{{signature}}'
WHERE message_type = 'sms'
  AND title = 'Blank';
