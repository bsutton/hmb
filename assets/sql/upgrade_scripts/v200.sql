ALTER TABLE site
ADD COLUMN name TEXT;

ALTER TABLE site
ADD COLUMN latitude REAL;

ALTER TABLE site
ADD COLUMN longitude REAL;

ALTER TABLE site
ADD COLUMN geocodeStatus TEXT;

ALTER TABLE site
ADD COLUMN geocodedAt TEXT;

CREATE TABLE mailing (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  notes TEXT,
  status TEXT NOT NULL DEFAULT 'draft',
  label_layout_id TEXT NOT NULL,
  route_origin TEXT,
  createdDate TEXT NOT NULL,
  modifiedDate TEXT NOT NULL
);

CREATE TABLE mailing_recipient (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  mailing_id INTEGER NOT NULL,
  customer_id INTEGER NOT NULL,
  contact_id INTEGER,
  site_id INTEGER,
  contact_name TEXT NOT NULL,
  customer_name TEXT NOT NULL,
  site_name TEXT,
  address_line_1 TEXT NOT NULL DEFAULT '',
  address_line_2 TEXT NOT NULL DEFAULT '',
  suburb TEXT NOT NULL DEFAULT '',
  state TEXT NOT NULL DEFAULT '',
  postcode TEXT NOT NULL DEFAULT '',
  selected INTEGER NOT NULL DEFAULT 1,
  route_order INTEGER,
  route_batch INTEGER,
  delivery_status TEXT NOT NULL DEFAULT 'pending',
  delivered_at TEXT,
  skipped_at TEXT,
  createdDate TEXT NOT NULL,
  modifiedDate TEXT NOT NULL,
  FOREIGN KEY (mailing_id) REFERENCES mailing(id),
  FOREIGN KEY (customer_id) REFERENCES customer(id),
  FOREIGN KEY (contact_id) REFERENCES contact(id),
  FOREIGN KEY (site_id) REFERENCES site(id)
);

CREATE INDEX mailing_recipient_mailing_idx
ON mailing_recipient(mailing_id);

CREATE UNIQUE INDEX mailing_recipient_customer_unq
ON mailing_recipient(mailing_id, customer_id);
