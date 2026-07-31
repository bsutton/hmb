-- Normalize SMS template ordering and system ownership.
UPDATE message_template
SET owner = 1
WHERE message_type = 'sms'
  AND (
    lower(trim(title)) = 'thank you for choosing me' OR
    lower(trim(title)) = 'thank you for choosing us'
  );

-- Give SMS templates a deterministic order so the chooser is predictable.
UPDATE message_template
SET ordinal = CASE title
  WHEN 'Blank' THEN 0
  WHEN 'Appointment Reminder' THEN 1
  WHEN 'Need Access Confirmation' THEN 2
  WHEN 'On My Way' THEN 3
  WHEN 'Arrived On Site' THEN 4
  WHEN 'Running Late' THEN 5
  WHEN 'Additional Scope Required' THEN 6
  WHEN 'Job Reschedule Notification' THEN 7
  WHEN 'Service Reminder' THEN 8
  WHEN 'Estimate Ready' THEN 9
  WHEN 'Invoice Sent' THEN 10
  WHEN 'Payment Reminder' THEN 11
  WHEN 'Invoice Overdue' THEN 12
  WHEN 'Job Completion Confirmation' THEN 13
  WHEN 'Follow-up After Service' THEN 14
  WHEN 'Thank You for Choosing Me' THEN 15
  WHEN 'Thank You for Choosing Us' THEN 16
  ELSE ordinal
END
WHERE message_type = 'sms'
  AND title IN (
    'Blank',
    'Appointment Reminder',
    'Need Access Confirmation',
    'On My Way',
    'Arrived On Site',
    'Running Late',
    'Additional Scope Required',
    'Job Reschedule Notification',
    'Service Reminder',
    'Estimate Ready',
    'Invoice Sent',
    'Payment Reminder',
    'Invoice Overdue',
    'Job Completion Confirmation',
    'Follow-up After Service',
    'Thank You for Choosing Me',
    'Thank You for Choosing Us'
  );
