CREATE TABLE time_entry (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id INTEGER NOT NULL,
    start_time TEXT NOT NULL,
    end_time TEXT,
    created_date TEXT NOT NULL,
    modified_date TEXT NOT NULL,
    FOREIGN KEY (task_id) REFERENCES task(id)
);