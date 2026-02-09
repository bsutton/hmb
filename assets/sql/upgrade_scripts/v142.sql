ALTER TABLE image_cache_variant
  ADD COLUMN created_date INTEGER NOT NULL
    DEFAULT (strftime('%s','now') * 1000);

ALTER TABLE image_cache_variant
  ADD COLUMN modified_date INTEGER NOT NULL
    DEFAULT (strftime('%s','now') * 1000);
