ALTER TABLE task ADD COLUMN category_id INTEGER REFERENCES category(id) ON DELETE SET NULL;
ALTER TABLE task ADD COLUMN effort_quantity REAL CHECK (effort_quantity > 0);
ALTER TABLE task ADD COLUMN effort_unit TEXT NOT NULL DEFAULT '';
ALTER TABLE task ADD COLUMN effort_notes TEXT NOT NULL DEFAULT '';
CREATE INDEX task_category_idx ON task(category_id);
