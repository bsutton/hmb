PRAGMA journal_mode = WAL;
PRAGMA synchronous = FULL;
CREATE TABLE IF NOT EXISTS switches (
 scope TEXT PRIMARY KEY, enabled INTEGER NOT NULL DEFAULT 0,
 ceiling INTEGER NOT NULL DEFAULT 0 CHECK(ceiling >= 0)
);
INSERT OR IGNORE INTO switches VALUES ('global',0,0),('text',0,0);
CREATE TABLE IF NOT EXISTS requests (
 tenant TEXT NOT NULL, subject TEXT NOT NULL, key TEXT NOT NULL,
 digest TEXT NOT NULL, provider TEXT NOT NULL, created INTEGER NOT NULL,
 reserved INTEGER NOT NULL CHECK(reserved > 0),
 charged INTEGER NOT NULL CHECK(charged >= 0),
 state TEXT NOT NULL CHECK(state IN ('pending','unknown','done')),
 PRIMARY KEY(tenant,subject,key)
);
CREATE INDEX IF NOT EXISTS usage_window ON requests(tenant,provider,created);
CREATE TABLE IF NOT EXISTS buckets (
 name TEXT PRIMARY KEY, tokens INTEGER NOT NULL, updated INTEGER NOT NULL
);
