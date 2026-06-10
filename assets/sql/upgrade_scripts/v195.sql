UPDATE message_template
SET message = REPLACE(message, '{{job.description}}', '{{job.summary}}')
WHERE message_type = 'sms' AND message LIKE '%{{job.description}}%';
