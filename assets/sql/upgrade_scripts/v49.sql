ALTER TABLE task ADD COLUMN job_id INTEGER;
UPDATE task SET job_id = jobId;

CREATE TABLE task_new (
    id INTEGER PRIMARY KEY,
    job_id INTEGER,  -- New column name
    name TEXT,
    description TEXT,
    effort_in_hours INTEGER,
    estimated_cost INTEGER,
    task_status_id INTEGER,
    createdDate TEXT,
    modifiedDate TEXT,
    billing_type TEXT,
    FOREIGN KEY (job_id) REFERENCES job(id),  -- Corrected foreign key constraint
    FOREIGN KEY (task_status_id) REFERENCES task_status(id)
);


INSERT INTO task_new (id, job_id, name, description, effort_in_hours, estimated_cost, task_status_id, createdDate, modifiedDate, billing_type)
SELECT id, job_id, name, description, effort_in_hours, estimated_cost, task_status_id, createdDate, modifiedDate, billing_type
FROM task;

drop table task;

ALTER TABLE task_new RENAME TO task;

