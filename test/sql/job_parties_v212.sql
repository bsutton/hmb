CREATE TABLE contact (
  id INTEGER PRIMARY KEY,
  firstName TEXT NOT NULL DEFAULT 'Test',
  surname TEXT NOT NULL DEFAULT 'Contact',
  mobileNumber TEXT NOT NULL DEFAULT '',
  landLine TEXT NOT NULL DEFAULT '',
  officeNumber TEXT NOT NULL DEFAULT '',
  emailAddress TEXT NOT NULL DEFAULT '',
  alternateEmail TEXT,
  xeroContactId TEXT,
  createdDate TEXT NOT NULL DEFAULT '2026-01-01T00:00:00',
  modifiedDate TEXT NOT NULL DEFAULT '2026-01-01T00:00:00',
  role_description TEXT NOT NULL DEFAULT ''
);
CREATE TABLE customer (id INTEGER PRIMARY KEY, billing_contact_id INTEGER);
CREATE TABLE customer_contact (customer_id INTEGER, contact_id INTEGER);
CREATE TABLE job (
  id INTEGER PRIMARY KEY, customer_id INTEGER, referrer_customer_id INTEGER,
  contact_id INTEGER, billing_contact_id INTEGER, referrer_contact_id INTEGER,
  tenant_contact_id INTEGER, billing_party TEXT
);
CREATE TABLE invoice (
  id INTEGER PRIMARY KEY, job_id INTEGER, billing_contact_id INTEGER
);
INSERT INTO contact(id, role_description) VALUES
  (1, ' Property manager '), (2, 'property MANAGER'),
  (3, 'Primary Contact'), (4, '');
INSERT INTO customer(id, billing_contact_id) VALUES (10, 1), (20, 3), (30, NULL);
INSERT INTO customer_contact VALUES (10, 1), (20, 2), (20, 3), (30, 4);
INSERT INTO job VALUES
  (1, 10, 20, 1, NULL, 2, 1, 'referrer'),
  (2, 10, NULL, 1, 3, NULL, NULL, 'customer'),
  (3, 30, NULL, NULL, NULL, NULL, NULL, 'customer');
INSERT INTO invoice VALUES (1, 1, NULL), (2, 1, 3), (3, 3, NULL);
