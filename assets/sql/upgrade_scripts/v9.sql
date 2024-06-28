insert into job_status (name, description, color_code, createdDate, modifiedDate) 
values ('Awaiting Payment', 'Job has been approved but we are awaiting payment.'
, '#FFD700', datetime('now'), datetime('now'));

insert into job_status (name, description, color_code, createdDate, modifiedDate) 
values ('Scheduled', 'Job has been approved and scheduled.'
, '#FFD700', datetime('now'), datetime('now'));


update job_status set name = 'In Progress' where name = 'In progress';
update job_status set name = 'To be Scheduled' where name = 'To be scheduled';

alter table customer add column description text;

