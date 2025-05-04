ALTER TABLE milestone ADD COLUMN billing_contact_id INTEGER REFERENCES contact(id);
