UPDATE message_template
SET message = 'Hey {{customer.name}},\n just a reminder about your appointment on {{event.start_date}} at {{event.start_time}}.\n Let me know if anything changes!\n {{signature}}'
WHERE id = 14;
UPDATE message_template
SET message = 'Hi {{customer.name}},\n I’ve wrapped up the job at {{site}}.\n Thanks for choosing me!\n If you have any thoughts or feedback,\n I''d love to here.\n {{signature}}'
WHERE id = 15;
UPDATE message_template
SET message = 'Hey {{customer.name}},\n your estimate for {{job.description}} is ready!\n The total comes to {{job.cost}}.\n Let me know if you’re good to go.\n {{signature}}'
WHERE id = 16;
UPDATE message_template
SET message = 'Hi {{customer.name}},\n just checking in to make sure everything’s good with the job I did at {{site}}.\n Need anything else?\n Just give me a shout.\n {{signature}}'
WHERE id = 17;
UPDATE message_template
SET message = 'Hey {{customer.name}},\n it’s time for your regular checkup on {{date.service}}.\n Let me know if that still works for you or if I need to reschedule.\n {{signature}}'
WHERE id = 18;
UPDATE message_template
SET message = 'Hi {{customer.name}},\n your invoice for the job at {{site}} is on its way to your email.\n Thanks for your prompt payment!\n {{signature}}'
WHERE id = 19;
UPDATE message_template
SET message = 'Hey {{customer.name}},\n just a reminder that your payment for the job at {{site}} is due by {{invoice.due_date}}.\n Thanks for taking care of that!\n {{signature}}'
WHERE id = 20;
UPDATE message_template
SET message = 'Hi {{customer.name}},\n I need to move your job on {{event.original_date}} to {{event.start_date}}.\n Sorry about the change and thanks for understanding!\n {{signature}}'
WHERE id = 21;
UPDATE message_template
SET message = 'Hi {{customer.name}},\n just wanted to say thanks for choosing me for the job!\n I appreciate your business and look forward to working with you again.\n {{signature}}'
WHERE id = 22;
UPDATE message_template
SET message = 'Hey {{customer.name}},\n just a quick note to let you know I''m running about {{delay.period}} behind.\n Sorry for the delay.\n {{signature}}'
WHERE id = 23;
UPDATE message_template
SET message = '{{customer.name}},\n {{signature}}'
WHERE id = 27;

UPDATE message_template
SET message = REPLACE(message, '\n', CHAR(10));

UPDATE message_template
SET message = REPLACE(message, '{{event.', '{{job_activity.');

UPDATE message_template
SET message = REPLACE(message, '{{site}}', '{{site.address}}')
WHERE message LIKE '%{{site}}%';

-- Rename the table
ALTER TABLE job_event RENAME TO job_activity;




