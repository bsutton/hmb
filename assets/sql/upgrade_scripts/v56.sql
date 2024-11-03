UPDATE message_template
SET message = REPLACE(message, 'delay_time', 'delay_period');

UPDATE message_template
SET message = REPLACE(message, 'job_address', 'site');
