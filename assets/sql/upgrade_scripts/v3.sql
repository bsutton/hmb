alter table task add column effort_in_hours integer;


alter table task add column estimated_cost integer;
alter table task add column charge_method integer; -- fixed inc materials, fixed ex materials, time & materials
alter table task add column task_status_id integer;


alter table job_status add column hidden integer; -- 1/0
update job_status set hidden = 0;
update job_status set hidden = 1 where description = 'Completed' or description = 'Rejected';

alter table job add column hourly_rate integer; -- in cents
alter table job add column call_out_fee integer; -- 
alter table customer add column default_hourly_rate integer; -- in cents

alter table system add column default_hourly_rate integer; -- in cents
alter table system add column terms_url text; -- link to t&cs.
alter table system add column default_call_out_fee integer; -- 


CREATE TABLE task_status(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        description TEXT,
        color_code TEXT,
        createdDate TEXT,
        modifiedDate TEXT
      );

INSERT INTO task_status (name, description, color_code, createdDate, modifiedDate)
VALUES
('To be scheduled', 'The customer has agreed to proceed but we have not set a start date', '#FFFFE0', datetime('now'), datetime('now')),
('Awaiting Materials', 'The job is paused until materials are available', '#D3D3D3', datetime('now'), datetime('now')),
('Completed', 'The Job is completed', '#90EE90', datetime('now'), datetime('now')),
('On Hold', 'The Job is on hold', '#FAFAD2', datetime('now'), datetime('now')),
('In progress', 'The Job is currently in progress', '#87CEFA', datetime('now'), datetime('now')),
('Cancelled', 'The Task has been cancelled by the customer', '#57CEFA', datetime('now'), datetime('now'));

CREATE TABLE check_list(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        description TEXT,
        list_type integer, -- 1 - global, 2 - default list, 3 - owned
        createdDate TEXT,
        modifiedDate TEXT
      );

CREATE TABLE check_list_item (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        check_list_id integer,
        description TEXT,
        item_type_id integer,
        cost integer,  -- the estimated or actual cost of the item. in cents.
        effort_in_hours integer, -- the labour, estimated or actual to do the work.
        createdDate TEXT,
        modifiedDate TEXT,
        FOREIGN KEY (check_list_id) references check_list(id),
        FOREIGN KEY (item_type_id) references check_list_item_type(id)
      );

   CREATE TABLE check_list_item_type(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        description TEXT,
        to_purchase integer,  -- this type of checklist item needs to be purchased
        color_code TEXT,
        createdDate TEXT,
        modifiedDate TEXT
      );   



INSERT INTO check_list_item_type (name, description, to_purchase, color_code, createdDate, modifiedDate)
VALUES
('Materials - buy', 'Materials need to be purchased', 1, '#FFFFE0', datetime('now'), datetime('now')),
('Materials - stock', 'Materials to be taken from stock', 0, '#D3D3D3', datetime('now'), datetime('now')),
('Tools - buy', 'Tool that needs to be purchased', 1, '#90EE90', datetime('now'), datetime('now')),
('Tools - own', 'Tool that we own', 0, '#FAFAD2',  datetime('now'), datetime('now')),
('Action', 'An action that needs to be taken', 0, '#87CEFA', datetime('now'), datetime('now'));


-- join table.
CREATE TABLE task_check_list(
        task_id integer,
        check_list_id integer,
        createdDate TEXT,
        modifiedDate TEXT, 
        FOREIGN KEY (task_id) references task(id),
        FOREIGN KEY (check_list_id) references check_list(id)
      );

-- join table.
CREATE TABLE check_list_check_list_item(
        check_list_id integer,
        check_list_item_id integer,
        createdDate TEXT,
        modifiedDate TEXT, 
        FOREIGN KEY (check_list_id) references check_list(id),
        FOREIGN KEY (check_list_item_id) references check_list_item(id)
      );      
