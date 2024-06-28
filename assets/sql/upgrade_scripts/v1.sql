CREATE TABLE IF NOT EXISTS "customer"(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        primaryFirstName TEXT,
        secondaryFirstName TEXT,
        createdDate TEXT,
        modifiedDate TEXT,
        disbarred INTEGER,
        customerType INTEGER
      );
CREATE TABLE IF NOT EXISTS "job"(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        createdDate TEXT,
        modifiedDate TEXT,
        customer_id INTEGER,
        site_id integer,
        contact_id integer,
        startDate TEXT,
        summary TEXT,
        description TEXT,
        address TEXT,
       job_status_id integer);
CREATE TABLE IF NOT EXISTS "task"(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        jobId INTEGER,
        name TEXT,
        description TEXT,
        completed INTEGER, 
        createdDate TEXT, 
        modifiedDate TEXT,
        FOREIGN KEY (jobId) REFERENCES "job"(id)
      );
CREATE TABLE IF NOT EXISTS "supplier"(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        description TEXT,
        createdDate TEXT,
        modifiedDate TEXT
      );
CREATE UNIQUE INDEX customer_name on customer(name);
CREATE UNIQUE INDEX supplier_name on supplier(name);
CREATE INDEX job_customer on job(customer_id);
CREATE TABLE site(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        addressLine1 TEXT,
        addressLine2 TEXT,
        suburb TEXT,
        state TEXT,
        postcode TEXT,
        createdDate TEXT,
        modifiedDate TEXT
      , `primary` integer);
CREATE TABLE customer_site(
        site_id integer,
        customer_id integer,
        createdDate TEXT,
        modifiedDate TEXT, 
        `primary` integer,
        FOREIGN KEY (site_id) references site(id),
        FOREIGN KEY (customer_id) references customer(id)
      );
CREATE UNIQUE INDEX customer_sites_unq ON customer_site(site_id, customer_id);
CREATE TABLE supplier_site(
        site_id integer,
        supplier_id, createdDate TEXT,
        modifiedDate TEXT,
        `primary` integer,
        FOREIGN KEY (site_id) references site(id),
        FOREIGN KEY (supplier_id) references supplier(id)
      );
CREATE UNIQUE INDEX supplier_site_unq ON supplier_site(site_id, supplier_id);
CREATE TABLE job_site(
        site_id integer,
        job_id integer,
        createdDate TEXT,
        modifiedDate TEXT,
        FOREIGN KEY (site_id) references site(id),
        FOREIGN KEY (job_id) references job(id)
      );
CREATE UNIQUE INDEX job_sites_unq ON job_site(site_id, job_id);
CREATE TABLE job_status(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        description TEXT,
        createdDate TEXT,
        modifiedDate TEXT
      );
CREATE INDEX job_status_idx ON job(job_status_id);
CREATE TABLE system(
        id INTEGER,
        fromEmail TEXT,
        BSB TEXT,
        accountNo TEXT,
        addressLine1 TEXT,
        addressLine2 TEXT,
        suburb TEXT,
        state TEXT,
        postcode TEXT,
        mobileNumber TEXT,
        landLine TEXT,
        officeNumber TEXT,
        emailAddress TEXT,
        webUrl TEXT,
        createdDate TEXT,
        modifiedDate TEXT
      );
CREATE TABLE customer_contact(
        contact_id integer,
        customer_id integer,
        createdDate TEXT,
        modifiedDate TEXT, 
        `primary` integer,
        FOREIGN KEY (contact_id) references contact(id),
        FOREIGN KEY (customer_id) references customer(id)
      );
CREATE UNIQUE INDEX customer_contacts_unq ON customer_contact(contact_id, customer_id);
CREATE TABLE supplier_contact(
        contact_id integer,
        supplier_id, integer,
        `primary` integer,
        createdDate TEXT,
        modifiedDate TEXT,
        FOREIGN KEY (contact_id) references contact(id),
        FOREIGN KEY (supplier_id) references supplier(id)
      );
CREATE UNIQUE INDEX supplier_contacts_unq ON supplier_contact(contact_id, supplier_id);
CREATE TABLE job_contact(
        contact_id integer,
        job_id integer,
        createdDate TEXT,
        modifiedDate TEXT,
        FOREIGN KEY (contact_id) references contact(id),
        FOREIGN KEY (job_id) references job(id)
      );
CREATE UNIQUE INDEX job_contacts_unq ON job_contact(contact_id, contact_id);
CREATE TABLE contact(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firstName TEXT,
        surname TEXT,
        addressLine1 TEXT,
        addressLine2 TEXT,
        suburb TEXT,
        state TEXT,
        postcode TEXT,
        mobileNumber TEXT,
        landLine TEXT,
        officeNumber TEXT,
        emailAddress TEXT,
        createdDate TEXT,
        modifiedDate TEXT
      );

