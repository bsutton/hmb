ALTER TABLE plaster_material_size
ADD COLUMN thickness INTEGER NOT NULL DEFAULT 100;

ALTER TABLE plaster_room
ADD COLUMN board_thickness INTEGER NOT NULL DEFAULT 100;

ALTER TABLE plaster_room_line
ADD COLUMN board_thickness_override INTEGER;
