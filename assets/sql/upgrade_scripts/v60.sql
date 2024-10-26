-- Rename the 'calloutFee' column to 'bookingFee' in the Job table
PRAGMA foreign_keys = off;
-- Step 1: Create a new Job table with the renamed column
CREATE TABLE Job_new (
    id INTEGER PRIMARY KEY,
    customer_id INTEGER,
    summary TEXT,
    description TEXT,
    start_date TEXT,
    site_id INTEGER,
    contact_id INTEGER,
    job_status_id INTEGER,
    hourly_rate INTEGER,
    booking_fee INTEGER,
    -- Renamed column
    last_active INTEGER,
    billing_type TEXT,
    created_date TEXT,
    modified_date TEXT
);
-- Step 2: Copy data from old Job table to new Job table
INSERT INTO Job_new (
        id,
        customer_id,
        summary,
        description,
        start_date,
        site_id,
        contact_id,
        job_status_id,
        hourly_rate,
        booking_fee,
        last_active,
        billing_type,
        created_date,
        modified_date
    )
SELECT id,
    customer_id,
    summary,
    description,
    startDate,
    site_id,
    contact_id,
    job_status_id,
    hourly_rate,
    call_out_fee,
    last_active,
    billing_type,
    createdDate,
    modifiedDate
FROM Job;
-- Step 3: Drop the old Job table and rename the new table
DROP TABLE Job;
ALTER TABLE Job_new
    RENAME TO Job;
-- Rename the 'defaultCalloutFee' column to 'defaultBookingFee' in the System table
-- Step 4: Create a new System table with the renamed column
CREATE TABLE System_new (
    id INTEGER PRIMARY KEY,
    from_email TEXT,
    bsb TEXT,
    account_no TEXT,
    address_line_1 TEXT,
    address_line_2 TEXT,
    suburb TEXT,
    state TEXT,
    postcode TEXT,
    mobile_number TEXT,
    landline TEXT,
    office_number TEXT,
    email_address TEXT,
    web_url TEXT,
    default_hourly_rate INTEGER,
    terms_url TEXT,
    default_booking_fee INTEGER,
    sim_card_no INTEGER,
    xero_client_id TEXT,
    xero_client_secret TEXT,
    business_name TEXT,
    business_number TEXT,
    business_number_label TEXT,
    country_code TEXT,
    payment_link_url TEXT,
    show_bsb_account_on_invoice INTEGER,
    show_payment_link_on_invoice INTEGER,
    use_metric_units INTEGER,
    logo_path TEXT,
    logo_aspect_ratio TEXT,
    billing_colour INTEGER,
    created_date TEXT,
    modified_date TEXT
);
-- Step 5: Copy data from old System table to new System table
INSERT INTO System_new (
        id,
        from_email,
        bsb,
        account_no,
        address_line_1,
        address_line_2,
        suburb,
        state,
        postcode,
        mobile_number,
        landline,
        office_number,
        email_address,
        web_url,
        default_hourly_rate,
        terms_url,
        default_booking_fee,
        sim_card_no,
        xero_client_id,
        xero_client_secret,
        business_name,
        business_number,
        business_number_label,
        country_code,
        payment_link_url,
        show_bsb_account_on_invoice,
        show_payment_link_on_invoice,
        use_metric_units,
        logo_path,
        logo_aspect_ratio,
        billing_colour,
        created_date,
        modified_date
    )
SELECT  id,
        fromEmail,
        bsb,
        accountNo,
        addressLine1,
        addressLine2,
        suburb,
        state,
        postcode,
        mobileNumber,
        landline,
        officeNumber,
        emailAddress,
        webUrl,
        default_hourly_rate,
        terms_url,
        default_call_out_fee,
        sim_card_no,
        xero_client_id,
        xero_client_secret,
        business_name,
        business_number,
        business_number_label,
        country_code,
        payment_link_url,
        show_bsb_account_on_invoice,
        show_payment_link_on_invoice,
        use_metric_units,
        logo_path,
        logo_aspect_ratio,
        billing_colour,
    createdDate,
    modifiedDate
FROM System;
-- Step 6: Drop the old System table and rename the new table
DROP TABLE System;
ALTER TABLE System_new
    RENAME TO System;
PRAGMA foreign_keys = on;