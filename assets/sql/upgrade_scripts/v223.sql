-- Preserve system customisations and user templates, including disabled SMS.
-- Existing address fields remain in their original position.
UPDATE message_template
SET message = message || CASE WHEN length(message) = 0 THEN ''
    ELSE char(10) || char(10) END || 'Site: {{site.address}}'
WHERE message_type = 'sms'
  AND instr(message, '{{site.address}}') = 0;
