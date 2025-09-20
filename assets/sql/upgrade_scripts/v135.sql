
-- 1) Add new columns to quote (NOT NULL with default for existing rows).
ALTER TABLE quote ADD COLUMN summary TEXT NOT NULL DEFAULT '';
ALTER TABLE quote ADD COLUMN description TEXT NOT NULL DEFAULT '';

-- 2) Backfill from job table using the FK quote.job_id -> job.id.
UPDATE quote
SET
  summary = COALESCE(
              (SELECT j.summary FROM job AS j WHERE j.id = quote.job_id),
              summary
            ),
  description = COALESCE(
                  (SELECT j.description FROM job AS j WHERE j.id = quote.job_id),
                  description
                );


-- Add a description column to quote_line_group.
-- NOT NULL with a default '' to keep existing rows valid.
ALTER TABLE quote_line_group
  ADD COLUMN description TEXT NOT NULL DEFAULT '';


-- Add a notes column to the job table.
-- Using NOT NULL with a default '' so existing rows remain valid.
ALTER TABLE job ADD COLUMN internal_notes TEXT NOT NULL DEFAULT '';
