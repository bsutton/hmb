ALTER TABLE customer ADD COLUMN billing_contact_id INTEGER REFERENCES contact(id);

ALTER TABLE invoice ADD COLUMN billing_contact_id INTEGER REFERENCES contact(id);


UPDATE customer
SET billing_contact_id = (
  SELECT MIN(contact_id)
  FROM customer_contact
  WHERE customer_contact.customer_id = customer.id
);


UPDATE invoice
SET billing_contact_id = (
  SELECT
    COALESCE(job.contact_id, customer.billing_contact_id)
  FROM job
  JOIN customer ON customer.id = job.customer_id
  WHERE job.id = invoice.job_id
);
