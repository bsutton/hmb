-- Replace booking_request JSON payload with explicit columns.
CREATE TABLE booking_request_new(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    remote_id TEXT NOT NULL UNIQUE,
    status INTEGER NOT NULL DEFAULT 0,
    name TEXT NOT NULL DEFAULT '',
    business_name TEXT NOT NULL DEFAULT '',
    first_name TEXT NOT NULL DEFAULT '',
    surname TEXT NOT NULL DEFAULT '',
    email TEXT NOT NULL DEFAULT '',
    phone TEXT NOT NULL DEFAULT '',
    description TEXT NOT NULL DEFAULT '',
    street TEXT NOT NULL DEFAULT '',
    suburb TEXT NOT NULL DEFAULT '',
    day1 TEXT NOT NULL DEFAULT '',
    day2 TEXT NOT NULL DEFAULT '',
    day3 TEXT NOT NULL DEFAULT '',
    createdDate TEXT NOT NULL,
    modifiedDate TEXT NOT NULL
);

INSERT INTO booking_request_new(
    id,
    remote_id,
    status,
    name,
    business_name,
    first_name,
    surname,
    email,
    phone,
    description,
    street,
    suburb,
    day1,
    day2,
    day3,
    createdDate,
    modifiedDate
)
SELECT
    id,
    remote_id,
    status,
    TRIM(
        CASE
            WHEN COALESCE(json_extract(payload, '$.data.name'), json_extract(payload, '$.name'), '') != ''
                THEN COALESCE(json_extract(payload, '$.data.name'), json_extract(payload, '$.name'), '')
            WHEN TRIM(
                COALESCE(json_extract(payload, '$.data.firstName'), json_extract(payload, '$.firstName'), '') || ' ' ||
                COALESCE(json_extract(payload, '$.data.surname'), json_extract(payload, '$.surname'), '')
            ) != ''
                THEN TRIM(
                    COALESCE(json_extract(payload, '$.data.firstName'), json_extract(payload, '$.firstName'), '') || ' ' ||
                    COALESCE(json_extract(payload, '$.data.surname'), json_extract(payload, '$.surname'), '')
                )
            ELSE COALESCE(json_extract(payload, '$.data.businessName'), json_extract(payload, '$.businessName'), '')
        END
    ) AS name,
    TRIM(COALESCE(json_extract(payload, '$.data.businessName'), json_extract(payload, '$.businessName'), '')) AS business_name,
    TRIM(COALESCE(json_extract(payload, '$.data.firstName'), json_extract(payload, '$.firstName'), '')) AS first_name,
    TRIM(COALESCE(json_extract(payload, '$.data.surname'), json_extract(payload, '$.surname'), '')) AS surname,
    TRIM(COALESCE(json_extract(payload, '$.data.email'), json_extract(payload, '$.email'), '')) AS email,
    TRIM(COALESCE(json_extract(payload, '$.data.phone'), json_extract(payload, '$.phone'), '')) AS phone,
    TRIM(COALESCE(json_extract(payload, '$.data.description'), json_extract(payload, '$.description'), '')) AS description,
    TRIM(COALESCE(json_extract(payload, '$.data.street'), json_extract(payload, '$.street'), '')) AS street,
    TRIM(COALESCE(json_extract(payload, '$.data.suburb'), json_extract(payload, '$.suburb'), '')) AS suburb,
    TRIM(COALESCE(json_extract(payload, '$.data.day1'), json_extract(payload, '$.day1'), '')) AS day1,
    TRIM(COALESCE(json_extract(payload, '$.data.day2'), json_extract(payload, '$.day2'), '')) AS day2,
    TRIM(COALESCE(json_extract(payload, '$.data.day3'), json_extract(payload, '$.day3'), '')) AS day3,
    createdDate,
    modifiedDate
FROM booking_request;

DROP TABLE booking_request;
ALTER TABLE booking_request_new RENAME TO booking_request;
