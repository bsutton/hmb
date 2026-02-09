CREATE TABLE image_cache_variant(
  photo_id INTEGER NOT NULL,
  variant TEXT NOT NULL,
  file_name TEXT NOT NULL,
  size INTEGER NOT NULL,
  last_access INTEGER NOT NULL,
  PRIMARY KEY (photo_id, variant)
);

CREATE INDEX idx_image_cache_variant_last_access
  ON image_cache_variant(last_access);
