INSERT INTO message_template (
        title,
        message,
        message_type,
        owner,
        enabled,
        createdDate,
        modifiedDate
    )
VALUES (
        'Blank',
        '',
        'sms',
        1,
        1,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    );
-- Step 1: Add the ordinal column to the table
ALTER TABLE message_template ADD COLUMN ordinal INTEGER;

-- Step 2: Set the blank message ordinal to 1
UPDATE message_template
SET ordinal = 1
WHERE message = '';

-- Step 3: Create a temporary table to calculate sequential ordinals
CREATE TEMPORARY TABLE temp_ordinals AS
SELECT id, ROW_NUMBER() OVER (ORDER BY createdDate) + 1 AS new_ordinal
FROM message_template
WHERE message != '';

-- Step 4: Update the original table with sequential ordinals
UPDATE message_template
SET ordinal = (SELECT new_ordinal FROM temp_ordinals WHERE temp_ordinals.id = message_template.id)
WHERE id IN (SELECT id FROM temp_ordinals);

-- Step 5: Drop the temporary table as it' s no longer needed DROP TABLE temp_ordinals;