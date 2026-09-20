-- Normalised contact defaults and job-specific contact/role assignments.
CREATE TABLE contact_role (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL COLLATE NOCASE UNIQUE CHECK (length(trim(name)) > 0),
  builtin INTEGER NOT NULL DEFAULT 0 CHECK (builtin IN (0, 1))
);

INSERT INTO contact_role(id, name, builtin) VALUES
  (1, 'Primary Contact', 1),
  (2, 'Billing Contact', 1),
  (3, 'Site Contact', 1),
  (4, 'Project Manager', 1),
  (5, 'Referrer', 1),
  (6, 'Owner', 1),
  (7, 'Tenant', 1),
  (8, 'Body Corporate Manager', 1),
  (9, 'Authoriser', 1);

INSERT OR IGNORE INTO contact_role(name)
SELECT trim(role_description) FROM contact
WHERE length(trim(role_description)) > 0
GROUP BY trim(role_description) COLLATE NOCASE
ORDER BY trim(role_description) COLLATE NOCASE;

ALTER TABLE contact ADD COLUMN default_role_id INTEGER REFERENCES contact_role(id);

UPDATE contact SET default_role_id = (
  SELECT id FROM contact_role
  WHERE name = trim(contact.role_description) COLLATE NOCASE
);

-- Retain a canonical display cache for existing contact queries, not free text.
UPDATE contact SET role_description = COALESCE(
  (SELECT name FROM contact_role WHERE id = contact.default_role_id), ''
);

CREATE TABLE job_party (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  job_id INTEGER NOT NULL REFERENCES job(id) ON DELETE CASCADE,
  contact_id INTEGER NOT NULL REFERENCES contact(id),
  role_id INTEGER NOT NULL REFERENCES contact_role(id),
  UNIQUE(job_id, contact_id, role_id)
);

CREATE UNIQUE INDEX job_party_single_primary_billing
ON job_party(job_id, role_id) WHERE role_id IN (1, 2);

INSERT INTO job_party(job_id, contact_id, role_id)
SELECT j.id, c.id, 1 FROM job j JOIN contact c ON c.id = j.contact_id;
INSERT INTO job_party(job_id, contact_id, role_id)
SELECT j.id, c.id, 2 FROM job j JOIN contact c ON c.id = j.billing_contact_id;
INSERT INTO job_party(job_id, contact_id, role_id)
SELECT j.id, c.id, 5 FROM job j JOIN contact c ON c.id = j.referrer_contact_id;
INSERT INTO job_party(job_id, contact_id, role_id)
SELECT j.id, c.id, 7 FROM job j JOIN contact c ON c.id = j.tenant_contact_id;

ALTER TABLE job ADD COLUMN bill_to_customer_id INTEGER REFERENCES customer(id);
ALTER TABLE job ADD COLUMN legacy_billing_contact_id INTEGER REFERENCES contact(id);

UPDATE job SET bill_to_customer_id =
  CASE WHEN billing_party = 'referrer' THEN referrer_customer_id
  ELSE customer_id END;

-- Preserve the actual legacy resolver order, including its primary-before-
-- lowest-id fallback. This is deliberately not the new-job default policy.
UPDATE job SET legacy_billing_contact_id = COALESCE(
  (SELECT id FROM contact WHERE id = job.billing_contact_id),
  (SELECT id FROM contact WHERE id = job.referrer_contact_id
     AND job.billing_party = 'referrer'),
  (SELECT c.id FROM customer cu JOIN contact c ON c.id = cu.billing_contact_id
     WHERE cu.id = job.bill_to_customer_id),
  (SELECT id FROM contact WHERE id = job.contact_id),
  (SELECT c.id FROM customer_contact cc JOIN contact c ON c.id = cc.contact_id
     WHERE cc.customer_id = job.bill_to_customer_id ORDER BY c.id LIMIT 1)
);

-- Old invoices must not acquire new recipients/customers when job defaults change.
ALTER TABLE invoice ADD COLUMN billing_customer_id INTEGER REFERENCES customer(id);
UPDATE invoice SET billing_customer_id = (
  SELECT bill_to_customer_id FROM job WHERE job.id = invoice.job_id
);
UPDATE invoice SET billing_contact_id = (
  SELECT legacy_billing_contact_id FROM job WHERE job.id = invoice.job_id
) WHERE billing_contact_id IS NULL;
