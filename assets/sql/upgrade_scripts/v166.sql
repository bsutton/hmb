ALTER TABLE plaster_room
ADD COLUMN ceiling_sheet_direction TEXT NOT NULL DEFAULT 'auto';

ALTER TABLE plaster_room_line
ADD COLUMN sheet_direction TEXT NOT NULL DEFAULT 'auto';
