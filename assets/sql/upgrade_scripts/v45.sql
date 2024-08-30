-- Rename the 'sms_template' table to 'message_template'
ALTER TABLE sms_template RENAME TO message_template;

-- Add the 'type' field to store the message type as a string
ALTER TABLE message_template ADD COLUMN message_type TEXT NOT NULL DEFAULT 'sms';


-- Update existing rows to have the correct messageType
UPDATE message_template SET messageType = 'sms' WHERE messageType IS NULL;

-- Rename the field 'type' to 'owner' in the message_template table
ALTER TABLE message_template RENAME COLUMN type TO owner;


