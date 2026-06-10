-- Refresh SMS system templates with aligned, clearer wording.
-- Use title-based updates (and owner/message type checks) so we do not rely
-- on fragile row ids, which can drift when users edit/add templates.
UPDATE message_template
SET message =
  'Hi {{contact.name}}, reminder for your appointment:\n'
  'Job: {{job.summary}}\n'
  'Date/Time: {{job_activity.start_date}} at {{job_activity.start_time}}\n'
  'Location: {{site.address}}\n'
  'Reply if anything changes.\n\n'
  '{{signature}}'
WHERE title = 'Appointment Reminder'
  AND owner = 1
  AND message_type = 'sms';

UPDATE message_template
SET message =
  'Hi {{contact.name}},\n'
  'Great news: your job "{{job.summary}}" is complete.\n'
  'Address: {{site.address}}\n'
  'If you have any feedback, I would love to hear it.\n\n'
  '{{signature}}'
WHERE title = 'Job Completion Confirmation'
  AND owner = 1
  AND message_type = 'sms';

UPDATE message_template
SET message =
  'Hi {{contact.name}},\n'
  'Your estimate for {{job.summary}} is ready.\n'
  'Total: {{job.cost}}.\n'
  'Reply when you are ready to proceed.\n\n'
  '{{signature}}'
WHERE title = 'Estimate Ready'
  AND owner = 1
  AND message_type = 'sms';

UPDATE message_template
SET message =
  'Hi {{contact.name}},\n'
  'Checking in on {{job.summary}} at {{site.address}}.\n'
  'Need anything else from me?\n\n'
  '{{signature}}'
WHERE title = 'Follow-up After Service'
  AND owner = 1
  AND message_type = 'sms';

UPDATE message_template
SET message =
  'Hi {{contact.name}},\n'
  'Reminder: your regular service for {{job.summary}} is due {{date.service}}.\n'
  'Location: {{site.address}}\n'
  'Reply and I can confirm the time.\n\n'
  '{{signature}}'
WHERE title = 'Service Reminder'
  AND owner = 1
  AND message_type = 'sms';

UPDATE message_template
SET message =
  'Hi {{contact.name}},\n'
  'Your invoice for {{job.summary}} at {{site.address}} has been sent.\n'
  'Thanks for your business.\n\n'
  '{{signature}}'
WHERE title = 'Invoice Sent'
  AND owner = 1
  AND message_type = 'sms';

UPDATE message_template
SET message =
  'Hi {{contact.name}},\n'
  'Quick reminder: payment for {{job.summary}} at {{site.address}}'
  ' is due on {{invoice.due_date}}.\n'
  'Thanks for your prompt payment.\n\n'
  '{{signature}}'
WHERE title = 'Payment Reminder'
  AND owner = 1
  AND message_type = 'sms';

UPDATE message_template
SET message =
  'Hi {{contact.name}},\n'
  'I need to reschedule {{job.summary}}.\n'
  'Original date: {{job_activity.original_date}}\n'
  'New date: {{job_activity.start_date}}\n'
  'Thanks for understanding.\n\n'
  '{{signature}}'
WHERE title = 'Job Reschedule Notification'
  AND owner = 1
  AND message_type = 'sms';

UPDATE message_template
SET message =
  'Hi {{contact.name}},\n'
  'Thank you for choosing me for {{job.summary}}.\n'
  'I appreciate your business.\n\n'
  '{{signature}}'
WHERE title = 'Thank You for Choosing Me'
  AND owner = 1
  AND message_type = 'sms';

UPDATE message_template
SET message =
  'Hi {{contact.name}},\n'
  'Thank you for choosing me for {{job.summary}}.\n'
  'I appreciate your business.\n\n'
  '{{signature}}'
WHERE title = 'Thank You for Choosing Us'
  AND owner = 1
  AND message_type = 'sms';

UPDATE message_template
SET message =
  'Hi {{contact.name}},\n'
  'I am running about {{delay.period}} late for {{job.summary}}.\n'
  'Location: {{site.address}}\n'
  'I appreciate your patience.\n\n'
  '{{signature}}'
WHERE title = 'Running Late'
  AND owner = 1
  AND message_type = 'sms';

-- Ensure legacy job description placeholders no longer appear in system SMS
-- templates.
UPDATE message_template
SET message = REPLACE(message, '{{job.description}}', '{{job.summary}}')
WHERE message_type = 'sms'
  AND owner = 1
  AND message LIKE '%{{job.description}}%';
