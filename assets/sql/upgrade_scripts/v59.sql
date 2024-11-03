CREATE TABLE tool (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  datePurchased TEXT,
  serialNumber TEXT,
  supplierId INTEGER,
  createdDate TEXT,
  modifiedDate TEXT,
  FOREIGN KEY (supplierId) REFERENCES Supplier(id)
);
