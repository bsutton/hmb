ALTER TABLE photo
ADD COLUMN cloud_file_id TEXT;

ALTER TABLE photo
ADD COLUMN cloud_md5 TEXT;

ALTER TABLE photo
ADD COLUMN cloud_modified_date TEXT;

CREATE INDEX photo_cloud_file_id_idx
ON photo(cloud_file_id);
