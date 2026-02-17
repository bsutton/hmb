ALTER TABLE job
  ADD COLUMN referrer_customer_id INTEGER REFERENCES customer(id);

ALTER TABLE job
  ADD COLUMN referrer_contact_id INTEGER REFERENCES contact(id);

ALTER TABLE job
  ADD COLUMN billing_party TEXT NOT NULL DEFAULT 'customer';
