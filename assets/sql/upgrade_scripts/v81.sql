update message_template 
set message = replace(message, '{{signature}}', ' {{signature}}');

UPDATE message_template
SET message = REPLACE(message, '{{customer_name}}', '{{customer_name}},')
WHERE ordinal = 1;


