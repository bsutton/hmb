ALTER TABLE job
ADD COLUMN tenant_contact_id INTEGER REFERENCES contact(id);
