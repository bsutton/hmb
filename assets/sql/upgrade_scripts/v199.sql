-- Normalize SMS template ordering and system ownership.
UPDATE message_template
SET owner = 1;

UPDATE message_template
SET ordinal = CASE title
  WHEN 'Blank' THEN 0
  WHEN 'Estimate Ready' THEN 1
  WHEN 'Appointment Reminder' THEN 2
  WHEN 'Service Reminder' THEN 3
  WHEN 'Need Access Confirmation' THEN 4
  WHEN 'On My Way' THEN 5
  WHEN 'Arrived On Site' THEN 6
  WHEN 'Running Late' THEN 7
  WHEN 'Job Reschedule Notification' THEN 8
  WHEN 'Additional Scope Required' THEN 9
  WHEN 'Job Completion Confirmation' THEN 10
  WHEN 'Follow-up After Service' THEN 11
  WHEN 'Invoice Sent' THEN 12
  WHEN 'Payment Reminder' THEN 13
  WHEN 'Invoice Overdue' THEN 14
  WHEN 'Thank You for Choosing Me' THEN 15
    ELSE ordinal
END