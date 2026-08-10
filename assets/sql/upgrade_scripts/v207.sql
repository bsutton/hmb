-- Repair system SMS template bodies that were assigned by fragile row ids in
-- v96. Match by title so databases with different row ids receive the correct
-- message without changing user-owned templates.
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
  'Your estimate for {{job.summary}} is ready and I''ve sent you the quote ' ||
  'via email.\n' ||
  'Reply if you have questions before approval.\n\n' ||
  '{{signature}}'
WHERE title = 'Estimate Ready'
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
  'Invoice for {{job.summary}} has been sent.\n' ||
  'If you have not received it yet, let me know and I can resend.\n\n' ||
  '{{signature}}'
WHERE title = 'Invoice Sent'
  AND owner = 1
  AND message_type = 'sms';

UPDATE message_template
SET message =
  'Hi {{contact.name}},\n' ||
  'Quick reminder: payment for {{job.summary}} is due on ' ||
  '{{invoice.due_date}}.\n' ||
  'Please let me know when it is paid.\n\n' ||
  '{{signature}}'
WHERE title = 'Payment Reminder'
  AND owner = 1
  AND message_type = 'sms';

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
  'Thanks for choosing me for {{job.summary}}.\n' ||
  'It''s been a pleasure to help. I appreciate the business.\n\n' ||
  '{{signature}}'
WHERE title IN ('Thank You for Choosing Me', 'Thank You for Choosing Us')
  AND owner = 1
  AND message_type = 'sms';

UPDATE message_template
SET message =
  'Hi {{contact.name}},\n' ||
  'Quick update: I''m running about {{delay.period}} late for ' ||
  '{{job.summary}}.\n' ||
  '{{signature}}'
WHERE title = 'Running Late'
  AND owner = 1
  AND message_type = 'sms';
