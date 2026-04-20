-- 0008_rating_ratee_name.sql — allow rating rows without a real ratee_id
--
-- For demo mode the rated players (陈子睿, 老王, Kevin...) don't exist as
-- auth.users rows. We keep ratee_id nullable (it already is — FK but no
-- NOT NULL) and store their display name in a new `ratee_name` column.
--
-- The unique constraint (match_id, rater_id, ratee_id) still works because
-- Postgres treats NULL values as distinct, so one rater can submit many
-- demo ratings (one per ratee_name) for the same match without collision.
-- To still prevent double-submission in demo mode, we add a partial unique
-- index that also considers ratee_name when ratee_id is null.

alter table ratings
  add column if not exists ratee_name text;

-- Partial unique: one row per (match, rater, ratee_name) when ratee_id IS NULL
create unique index if not exists ratings_demo_unique
  on ratings (match_id, rater_id, ratee_name)
  where ratee_id is null;
