
-- Add the new column for color codes
ALTER TABLE job_status ADD COLUMN color_code TEXT;

-- Insert new rows with the current timestamp for createdDate and modifiedDate
INSERT INTO job_status (name, description, color_code, createdDate, modifiedDate)
VALUES
('Prospecting', 'A customer has contacted us about a potential job', '#ADD8E6', datetime('now'), datetime('now')),
('To be scheduled', 'The customer has agreed to proceed but we have not set a start date', '#FFFFE0', datetime('now'), datetime('now')),
('Awaiting Materials', 'The job is paused until materials are available', '#D3D3D3', datetime('now'), datetime('now')),
('Completed', 'The Job is completed', '#90EE90', datetime('now'), datetime('now')),
('To be Billed', 'The Job is completed and needs to be billed', '#FFA07A', datetime('now'), datetime('now')),
('Progress Payment', 'A Job stage has been completed and a progress payment is to be billed', '#F08080', datetime('now'), datetime('now')),
('Rejected', 'The Job was rejected by the Customer', '#FFB6C1', datetime('now'), datetime('now')),
('On Hold', 'The Job is on hold', '#FAFAD2', datetime('now'), datetime('now')),
('In progress', 'The Job is currently in progress', '#87CEFA', datetime('now'), datetime('now'));


insert into system (id, createdDate, modifiedDate)
values (1, datetime('now'), datetime('now'));