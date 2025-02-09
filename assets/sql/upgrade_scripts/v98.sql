-- Add a new column for the quote state with a default of 'reviewing' and a check constraint
ALTER TABLE quote
ADD COLUMN state TEXT NOT NULL DEFAULT 'reviewing' CHECK (state IN ('rejected', 'accepted', 'sent', 'reviewing'));

-- Add a new column for the date the quote was sent (stored as an ISO8601 string)
ALTER TABLE quote
ADD COLUMN date_sent TEXT;

-- Add a new column for the date the quote was accepted (stored as an ISO8601 string)
ALTER TABLE quote
ADD COLUMN date_accepted TEXT;


