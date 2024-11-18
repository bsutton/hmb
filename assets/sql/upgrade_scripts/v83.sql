UPDATE message_template
SET message = REPLACE(message, '{{new_date}}', '{{appointment_date}},');
