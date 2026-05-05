ALTER TABLE plaster_material_size
ADD COLUMN attribute_mask INTEGER NOT NULL DEFAULT 0;

ALTER TABLE plaster_room
ADD COLUMN attribute_mask INTEGER NOT NULL DEFAULT 0;

ALTER TABLE plaster_room_line
ADD COLUMN attribute_mask_override INTEGER;
