-- rename the table Job to job and System to system.
ALTER TABLE "System"
    RENAME TO system_old;
-- Step 1: Create a new table "system" 
CREATE TABLE system (
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
    payment_terms_in_days INTEGER,
    payment_options TEXT,
    created_date TEXT,
    modified_date TEXT
);
-- Step 2: Copy data from the old "System" table to the new "system" table
INSERT INTO system (
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
        payment_terms_in_days,
        payment_options,
        created_date,
        modified_date
    )
select id,
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
    billing_colour,
    logo_path,
    logo_aspect_ratio,
    payment_terms_in_days,
    payment_options,
    created_date,
    modified_date
from system_old;
drop table system_old;
alter table "Job"
    rename to job_new;
alter table job_new
    rename to job;