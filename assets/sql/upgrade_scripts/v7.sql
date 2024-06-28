-- join table - missing on production systems.
 CREATE TABLE IF NOT EXISTS  check_list_check_list_item(
        check_list_id integer,
        check_list_item_id integer,
        createdDate TEXT,
        modifiedDate TEXT, 
        FOREIGN KEY (check_list_id) references check_list(id),
        FOREIGN KEY (check_list_item_id) references check_list_item(id)
      );      
