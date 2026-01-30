delete from sms_template where type = 1;

INSERT INTO sms_template (title, message, type, disabled, createdDate, modifiedDate)
VALUES ('Appointment Reminder', 'Hey {{customer_name}}, just a reminder about your appointment on {{appointment_date}} at {{appointment_time}}. Let me know if anything changes!', 1, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

INSERT INTO sms_template (title, message, type, disabled, createdDate, modifiedDate)
VALUES ('Job Completion Confirmation', 'Hi {{customer_name}}, I’ve wrapped up the job at {{job_address}}. Thanks for choosing me! If you have any thoughts or feedback, I’d love to here.', 1, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

INSERT INTO sms_template (title, message, type, disabled, createdDate, modifiedDate)
VALUES ('Estimate Ready', 'Hey {{customer_name}}, your estimate for {{job_description}} is ready! The total comes to {{job_cost}}. Let me know if you’re good to go.', 1, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

INSERT INTO sms_template (title, message, type, disabled, createdDate, modifiedDate)
VALUES ('Follow-up After Service', 'Hi {{customer_name}}, just checking in to make sure everything’s good with the job I did at {{job_address}}. Need anything else? Just give me a shout.', 1, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

INSERT INTO sms_template (title, message, type, disabled, createdDate, modifiedDate)
VALUES ('Service Reminder', 'Hey {{customer_name}}, it’s time for your regular checkup on {{service_date}}. Let me know if that still works for you or if I need to reschedule.', 1, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

INSERT INTO sms_template (title, message, type, disabled, createdDate, modifiedDate)
VALUES ('Invoice Sent', 'Hi {{customer_name}}, your invoice for the job at {{job_address}} is on its way to your email. Thanks for your prompt payment!', 1, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

INSERT INTO sms_template (title, message, type, disabled, createdDate, modifiedDate)
VALUES ('Payment Reminder', 'Hey {{customer_name}}, just a reminder that your payment for the job at {{job_address}} is due by {{due_date}}. Thanks for taking care of that!', 1, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

INSERT INTO sms_template (title, message, type, disabled, createdDate, modifiedDate)
VALUES ('Job Reschedule Notification', 'Hi {{customer_name}}, I need to move your job on {{original_date}} to {{new_date}}. Sorry about the change and thanks for understanding!', 1, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

INSERT INTO sms_template (title, message, type, disabled, createdDate, modifiedDate)
VALUES ('Thank You for Choosing Me', 'Hi {{customer_name}}, just wanted to say thanks for choosing me for the job! I appreciate your business and look forward to working with you again.', 1, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

INSERT INTO sms_template (title, message, type, disabled, createdDate, modifiedDate)
VALUES ('Running Late - Short Delay', 'Hey {{customer_name}}, just a quick note to let you know I’m running about {{delay_time}} minutes behind. Sorry for the delay—I’ll be there soon!', 1, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

INSERT INTO sms_template (title, message, type, disabled, createdDate, modifiedDate)
VALUES ('Running Late - Traffic', 'Hi {{customer_name}}, stuck in a bit of traffic, so I’ll be there closer to {{new_arrival_time}}. Thanks for your patience!', 1, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

INSERT INTO sms_template (title, message, type, disabled, createdDate, modifiedDate)
VALUES ('Running Late - Previous Job Overrun', 'Hi {{customer_name}}, the last job took longer than expected, so I’m running a bit late. I should be there by {{new_arrival_time}}. Appologies!', 1, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

INSERT INTO sms_template (title, message, type, disabled, createdDate, modifiedDate)
VALUES ('Running Late - Weather Conditions', 'Hey {{customer_name}}, the weather’s slowing me down a bit. I’m aiming to be there by {{new_arrival_time}}. Thanks for understanding!', 1, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);


-- Rename the 'disabled' column to 'enabled'
ALTER TABLE sms_template RENAME COLUMN disabled TO enabled;

-- Invert the logic: Update the 'enabled' column to reflect the inverted value of the old 'disabled' column
UPDATE sms_template SET enabled = CASE WHEN enabled = 1 THEN 0 ELSE 1 END;
