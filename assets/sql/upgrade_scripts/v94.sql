-- SQL Update for Job Event Table
ALTER TABLE job_event
ADD COLUMN notes TEXT;
ALTER TABLE job_event
ADD COLUMN status TEXT DEFAULT 'proposed';

ALTER TABLE job_event
ADD COLUMN notice_sent_date DATETIME;