-- Add/refresh tradie-oriented SMS template defaults.
-- Existing system templates are updated by title so IDs do not matter.
-- New templates are added only if they do not already exist.

UPDATE message_template
SET message =
  'Hi {{contact.name}},\n' ||
  'Friendly reminder for your job:\n' ||
  '{{job.summary}}\n' ||
  'Date: {{job_activity.start_date}}\n' ||
  'Time: {{job_activity.start_time}}\n' ||
  'Location: {{site.address}}\n' ||
  'Let me know if anything changes.\n\n' ||
  '{{signature}}'
WHERE title = 'Appointment Reminder'
  AND owner = 1
  AND message_type = 'sms';

UPDATE message_template
SET message =
  'Hi {{contact.name}},\n' ||
  'Before I start {{job.summary}}, I need access details for {{site.address}}.\n' ||
  'Please confirm any required gate codes, lock codes, parking, and/or key handover details.\n\n' ||
  '{{signature}}'
WHERE title = 'Need Access Confirmation'
  AND owner = 1
  AND message_type = 'sms';

INSERT INTO message_template (
  title,
  message,
  message_type,
  owner,
  enabled,
  ordinal,
  createdDate,
  modifiedDate
)
SELECT
  'Need Access Confirmation',
  'Hi {{contact.name}},\n' ||
  'Before I start {{job.summary}}, I need access details for {{site.address}}.\n' ||
  'Please confirm any required gate codes, lock codes, parking, and/or key handover details.\n\n' ||
  '{{signature}}',
  'sms',
  1,
  1,
  COALESCE((SELECT MAX(ordinal) FROM message_template), 0) + 1,
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP
WHERE NOT EXISTS (
  SELECT 1 FROM message_template WHERE title = 'Need Access Confirmation'
);

UPDATE message_template
SET message =
  'Hi {{contact.name}},\n' ||
  'I''m on my way to {{job.summary}} at {{site.address}}.\n' ||
  'ETA: {{delay.period}}.\n' ||
  'I will call/text when I''m nearby.\n\n' ||
  '{{signature}}'
WHERE title = 'On My Way'
  AND owner = 1
  AND message_type = 'sms';

INSERT INTO message_template (
  title,
  message,
  message_type,
  owner,
  enabled,
  ordinal,
  createdDate,
  modifiedDate
)
SELECT
  'On My Way',
  'Hi {{contact.name}},\n' ||
  'I''m on my way to {{job.summary}} at {{site.address}}.\n' ||
  'ETA: {{delay.period}}.\n' ||
  'I will call/text when I''m nearby.\n\n' ||
  '{{signature}}',
  'sms',
  1,
  1,
  COALESCE((SELECT MAX(ordinal) FROM message_template), 0) + 1,
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP
WHERE NOT EXISTS (
  SELECT 1 FROM message_template WHERE title = 'On My Way'
);

UPDATE message_template
SET message =
  'Hi {{contact.name}},\n' ||
  'I have arrived at {{site.address}} for {{job.summary}}.\n' ||
  'I''ll start shortly and keep you updated on progress.\n\n' ||
  '{{signature}}'
WHERE title = 'Arrived On Site'
  AND owner = 1
  AND message_type = 'sms';

INSERT INTO message_template (
  title,
  message,
  message_type,
  owner,
  enabled,
  ordinal,
  createdDate,
  modifiedDate
)
SELECT
  'Arrived On Site',
  'Hi {{contact.name}},\n' ||
  'I have arrived at {{site.address}} for {{job.summary}}.\n' ||
  'I''ll start shortly and keep you updated on progress.\n\n' ||
  '{{signature}}',
  'sms',
  1,
  1,
  COALESCE((SELECT MAX(ordinal) FROM message_template), 0) + 1,
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP
WHERE NOT EXISTS (
  SELECT 1 FROM message_template WHERE title = 'Arrived On Site'
);

UPDATE message_template
SET message =
  'Hi {{contact.name}},\n' ||
  'Quick update: I''m running about {{delay.period}} late for {{job.summary}}.\n' ||
  '{{signature}}'
WHERE title = 'Running Late'
  AND owner = 1
  AND message_type = 'sms';

UPDATE message_template
SET message =
  'Hi {{contact.name}},\n' ||
  'While on {{job.summary}} I found some issues that are going to require extra work:\n' ||
  '{{scope_details}}\n' ||
  'Reply "yes" if you want me to proceed, or tell me your preference.\n\n' ||
  '{{signature}}'
WHERE title = 'Additional Scope Required'
  AND owner = 1
  AND message_type = 'sms';

INSERT INTO message_template (
  title,
  message,
  message_type,
  owner,
  enabled,
  ordinal,
  createdDate,
  modifiedDate
)
SELECT
  'Additional Scope Required',
  'Hi {{contact.name}},\n' ||
  'While on {{job.summary}} I found some issues that are going to require extra work:\n' ||
  '{{scope_details}}\n' ||
  'Reply "yes" if you want me to proceed, or tell me your preference.\n\n' ||
  '{{signature}}',
  'sms',
  1,
  1,
  COALESCE((SELECT MAX(ordinal) FROM message_template), 0) + 1,
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP
WHERE NOT EXISTS (
  SELECT 1 FROM message_template WHERE title = 'Additional Scope Required'
);

UPDATE message_template
SET message =
  'Hi {{contact.name}},\n' ||
  'I need to reschedule {{job.summary}}.\n' ||
  'Original date: {{job_activity.original_date}}\n' ||
  'New date/time: {{job_activity.start_date}} {{job_activity.start_time}}\n' ||
  'Please confirm if this works for you.\n\n' ||
  '{{signature}}'
WHERE title = 'Job Reschedule Notification'
  AND owner = 1
  AND message_type = 'sms';

UPDATE message_template
SET message =
  'Hi {{contact.name}},\n' ||
  'Reminder: your service for {{job.summary}} is due on {{date.service}}.\n' ||
  'Location: {{site.address}}\n' ||
  'Reply if you need to change the time.\n\n' ||
  '{{signature}}'
WHERE title = 'Service Reminder'
  AND owner = 1
  AND message_type = 'sms';

UPDATE message_template
SET message =
  'Hi {{contact.name}},\n' ||
  'Your estimate for {{job.summary}} is ready and I''ve sent you the quote via email.\n' ||
  'Reply if you have questions before approval.\n\n' ||
  '{{signature}}'
WHERE title = 'Estimate Ready'
  AND owner = 1
  AND message_type = 'sms';

UPDATE message_template
SET message =
  'Hi {{contact.name}},\n' ||
  'Invoice for {{job.summary}} has been sent.\n' ||
  'If you have not received it yet, let me know and I can resend.\n\n' ||
  '{{signature}}'
WHERE title = 'Invoice Sent'
  AND owner = 1
  AND message_type = 'sms';

UPDATE message_template
SET message =
  'Hi {{contact.name}},\n' ||
  'Quick reminder: payment for {{job.summary}} is due on {{invoice.due_date}}.\n' ||
  'Please let me know when it is paid.\n\n' ||
  '{{signature}}'
WHERE title = 'Payment Reminder'
  AND owner = 1
  AND message_type = 'sms';

UPDATE message_template
SET message =
  'Hi {{contact.name}},\n' ||
  'Just following up on {{invoice.number}} for {{job.summary}} which is overdue.\n' ||
  'Appreciate it if you can sort this out asap.\n\n' ||
  '{{signature}}'
WHERE title = 'Invoice Overdue'
  AND owner = 1
  AND message_type = 'sms';

INSERT INTO message_template (
  title,
  message,
  message_type,
  owner,
  enabled,
  ordinal,
  createdDate,
  modifiedDate
)
SELECT
  'Invoice Overdue',
  'Hi {{contact.name}},\n' ||
  'Just following up on {{invoice.number}} for {{job.summary}} which is overdue.\n' ||
  'Appreciate it if you can sort this out asap.\n\n' ||
  '{{signature}}',
  'sms',
  1,
  1,
  COALESCE((SELECT MAX(ordinal) FROM message_template), 0) + 1,
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP
WHERE NOT EXISTS (
  SELECT 1 FROM message_template WHERE title = 'Invoice Overdue'
);

UPDATE message_template
SET message =
  'Hi {{contact.name}},\n' ||
  'Your job {{job.summary}} is complete.\n' ||
  'Please confirm that you are happy with the work.\n' ||
  'If you have any concerns please give me a call.\n\n' ||
  '{{signature}}'
WHERE title = 'Job Completion Confirmation'
  AND owner = 1
  AND message_type = 'sms';

UPDATE message_template
SET message =
  'Hi {{contact.name}},\n' ||
  'Just checking in after completing {{job.summary}}.\n' ||
  'How is everything looking at {{site.address}}?\n' ||
  'Reply if anything is needed.\n\n' ||
  '{{signature}}'
WHERE title = 'Follow-up After Service'
  AND owner = 1
  AND message_type = 'sms';

UPDATE message_template
SET message =
  'Hi {{contact.name}},\n' ||
  'Thanks for choosing me for {{job.summary}}.\n' ||
  'It''s been a pleasure to help. I appreciate the business.\n\n' ||
  '{{signature}}'
WHERE title = 'Thank You for Choosing Me'
  AND owner = 1
  AND message_type = 'sms';

UPDATE message_template
SET message =
  'Hi {{contact.name}},\n' ||
  'Thanks for choosing me for {{job.summary}}.\n' ||
  'It''s been a pleasure to help. I appreciate the business.\n\n' ||
  '{{signature}}'
WHERE title = 'Thank You for Choosing Us'
  AND owner = 1
  AND message_type = 'sms';

DELETE FROM message_template
WHERE owner = 1
  AND message_type = 'sms'
  AND title = 'Materials Update';
