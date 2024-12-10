ALTER TABLE job_status
    RENAME TO job_status_old;
CREATE TABLE job_status (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    description TEXT,
    color_code TEXT,
    hidden INTEGER DEFAULT 0,
    status_enum TEXT ,
    ordinal INTEGER,
    createdDate TEXT DEFAULT CURRENT_TIMESTAMP,
    modifiedDate TEXT DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO job_status (
        id,
        name,
        description,
        color_code,
        hidden,
        status_enum,
        ordinal,
        createdDate,
        modifiedDate
    )
SELECT id,
    name,
    description,
    color_code,
    hidden,
    CASE
        WHEN name = 'Prospecting' THEN 'preStart'
        WHEN name = 'To be Scheduled' THEN 'preStart'
        WHEN name = 'Awaiting Materials' THEN 'onHold'
        WHEN name = 'Completed' THEN 'finalised'
        WHEN name = 'To be Billed' THEN 'finalised'
        WHEN name = 'Progress Payment' THEN 'finalised'
        WHEN name = 'Rejected' THEN 'onHold'
        WHEN name = 'On Hold' THEN 'onHold'
        WHEN name = 'In Progress' THEN 'progressing'
        WHEN name = 'Awaiting Payment' THEN 'onHold'
        WHEN name = 'Scheduled' THEN 'preStart'
        WHEN name = 'Quoting' THEN 'preStart'
        WHEN name = 'Awaiting Approval' THEN 'preStart'
        ELSE NULL
    END AS status_enum,
    ordinal,
    COALESCE(createdDate, CURRENT_TIMESTAMP) AS createdDate,
    COALESCE(modifiedDate, CURRENT_TIMESTAMP) AS modifiedDate
FROM job_status_old;
drop table job_status_old;
update job_status
set status_enum = 'preStart'
where name = 'Quoting';
update job_status
set ordinal = ordinal + 1
where ordinal > 2;
insert into job_status (
        name,
        description,
        color_code,
        hidden,
        status_enum,
        ordinal
    )
values(
        'Awaiting Approval',
        'Waiting on the client to approve quote',
        '#ADD8E6',
        0,
        'preStart',
        3
    );
update job_status
set createdDate = CURRENT_TIMESTAMP,
    modifiedDate = CURRENT_TIMESTAMP
where createdDate is null;
update job_status
set status_enum = 'finalised'
where name = 'Rejected';
update job_status
set hidden = 0
where hidden is null;