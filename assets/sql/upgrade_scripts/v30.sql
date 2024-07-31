drop table photos;
CREATE TABLE photo (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  taskId INTEGER NOT NULL,
  filePath TEXT NOT NULL,
  comment TEXT,
  created_date TEXT NOT NULL,
  modified_date TEXT NOT NULL,
  FOREIGN KEY (taskId) REFERENCES task(id)
);
