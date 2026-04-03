ALTER TABLE plaster_project
ADD COLUMN wall_fixing_face_width INTEGER NOT NULL DEFAULT 450;

ALTER TABLE plaster_project
ADD COLUMN ceiling_fixing_face_width INTEGER NOT NULL DEFAULT 450;

ALTER TABLE plaster_room
ADD COLUMN ceiling_framing_spacing_override INTEGER;

ALTER TABLE plaster_room
ADD COLUMN ceiling_framing_offset_override INTEGER;

ALTER TABLE plaster_room
ADD COLUMN ceiling_fixing_face_width_override INTEGER;

ALTER TABLE plaster_room_line
ADD COLUMN fixing_face_width_override INTEGER;
