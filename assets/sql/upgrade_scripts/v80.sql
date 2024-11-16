update message_template
set message = '{{customer_name}}'

where message = '';


UPDATE message_template
SET message = message || '{{signature}}';