-- 0010_match_livekit.sql — Extend matches/events for LiveKit live streaming

-- 1. matches: add status + livekit fields
ALTER TABLE matches ADD COLUMN IF NOT EXISTS status text DEFAULT 'upcoming'
  CHECK (status IN ('upcoming','live','finished'));
ALTER TABLE matches ADD COLUMN IF NOT EXISTS livekit_room text;
ALTER TABLE matches ADD COLUMN IF NOT EXISTS started_at timestamptz;
ALTER TABLE matches ADD COLUMN IF NOT EXISTS ended_at timestamptz;

-- 2. Migrate existing data from done bool → status
UPDATE matches SET status = 'finished' WHERE done = true AND status = 'upcoming';
UPDATE matches SET status = 'upcoming' WHERE done = false AND status IS NULL;

-- 3. events: expand status CHECK to include new lifecycle states
ALTER TABLE events DROP CONSTRAINT IF EXISTS events_status_check;
ALTER TABLE events ADD CONSTRAINT events_status_check
  CHECK (status IN ('draft','registering','scheduling','ongoing','completed','done'));

-- 4. Indexes for live-match queries
CREATE INDEX IF NOT EXISTS idx_matches_status ON matches(status);
CREATE INDEX IF NOT EXISTS idx_matches_event_status ON matches(event_id, status);

-- 5. Enable Realtime on matches table
ALTER PUBLICATION supabase_realtime ADD TABLE matches;

-- 6. RLS: everyone can read matches
CREATE POLICY "matches_select_all" ON matches FOR SELECT USING (true);

-- 7. RLS: only event creator can update match rows
CREATE POLICY "matches_update_by_event_creator" ON matches FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM events
    WHERE events.id = matches.event_id
    AND events.creator_id = auth.uid()
  )
);

-- 8. RLS: only event creator can insert matches (schedule generation)
CREATE POLICY "matches_insert_by_event_creator" ON matches FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM events
    WHERE events.id = matches.event_id
    AND events.creator_id = auth.uid()
  )
);

-- 9. RLS: only event creator can insert goals
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'goals_insert_by_event_creator'
  ) THEN
    CREATE POLICY "goals_insert_by_event_creator" ON goals FOR INSERT WITH CHECK (
      EXISTS (
        SELECT 1 FROM matches
        JOIN events ON events.id = matches.event_id
        WHERE matches.id = goals.match_id
        AND events.creator_id = auth.uid()
      )
    );
  END IF;
END $$;
