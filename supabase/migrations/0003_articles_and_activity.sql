-- supabase/migrations/0003_articles_and_activity.sql

-- Articles table for editorial content
CREATE TABLE IF NOT EXISTS articles (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id  UUID REFERENCES profiles(id),
  title      TEXT NOT NULL,
  summary    TEXT,
  body       TEXT,
  cover_url  TEXT,
  category   TEXT NOT NULL DEFAULT 'analysis',
  read_time_min INT DEFAULT 5,
  view_count INT DEFAULT 0,
  comment_count INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Activity fields on posts for structured sport data (Strava-style)
ALTER TABLE posts ADD COLUMN IF NOT EXISTS match_count  INT;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS win_count    INT;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS play_duration INT; -- minutes
ALTER TABLE posts ADD COLUMN IF NOT EXISTS venue        TEXT;
