UPDATE message_template
SET message = REPLACE(message, 'customer_name', 'customer.name')
WHERE message LIKE '%customer_name%';
-- Update for appointment_date
UPDATE message_template
SET message = REPLACE(
        message,
        '{{appointment_date}}',
        '{{event.start_date}}'
    )
WHERE message LIKE '%{{appointment_date}}%';
-- Update for appointment_time
UPDATE message_template
SET message = REPLACE(
        message,
        '{{appointment_time}}',
        '{{event.start_time}}'
    )
WHERE message LIKE '%{{appointment_time}}%';
-- Update for job_description
UPDATE message_template
SET message = REPLACE(
        message,
        '{{job_description}}',
        '{{job.description}}'
    )
WHERE message LIKE '%{{job_description}}%';
-- Update for job_cost
UPDATE message_template
SET message = REPLACE(message, '{{job_cost}}', '{{job.cost}}')
WHERE message LIKE '%{{job_cost}}%';
-- Update for service_date
UPDATE message_template
SET message = REPLACE(message, '{{service_date}}', '{{date.service}}')
WHERE message LIKE '%{{service_date}}%';
-- Update for due_date
UPDATE message_template
SET message = REPLACE(message, '{{due_date}}', '{{invoice.due_date}}')
WHERE message LIKE '%{{due_date}}%';
-- Update for original_date
UPDATE message_template
SET message = REPLACE(
        message,
        '{{original_date}}',
        '{{event.original_date}}'
    )
WHERE message LIKE '%{{original_date}}%';
-- Update for delay_period
UPDATE message_template
SET message = REPLACE(message, '{{delay_period}}', '{{delay.period}}')
WHERE message LIKE '%{{delay_period}}%';


UPDATE message_template
SET message = REPLACE(
    REPLACE(
        REPLACE(message, ',', ',\n'), 
        '.', '.\n'
    ),
    '!', '!\n'
)
WHERE message LIKE '%,%' OR message LIKE '%.%' OR message LIKE '%!%';

UPDATE message_template
SET message = REPLACE(
    REPLACE(
        REPLACE(message, ',\n', ','),
        '.\n', '.'
    ),
    '!\n', '!'
);