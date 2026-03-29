ALTER TABLE plaster_project
ADD COLUMN wall_stud_spacing INTEGER NOT NULL DEFAULT 6000;

ALTER TABLE plaster_project
ADD COLUMN wall_stud_offset INTEGER NOT NULL DEFAULT 0;

ALTER TABLE plaster_project
ADD COLUMN ceiling_framing_spacing INTEGER NOT NULL DEFAULT 4500;

ALTER TABLE plaster_project
ADD COLUMN ceiling_framing_offset INTEGER NOT NULL DEFAULT 0;

ALTER TABLE plaster_room_line
ADD COLUMN stud_spacing_override INTEGER;

ALTER TABLE plaster_room_line
ADD COLUMN stud_offset_override INTEGER;
