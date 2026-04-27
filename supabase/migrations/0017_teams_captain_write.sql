-- 0017_teams_captain_write.sql
-- Add missing insert/delete RLS policies for the teams table.
-- insert: fixes the currently-unprotected team registration.
-- delete: enables cancel-registration feature.

CREATE POLICY "teams captain insert"
  ON public.teams FOR INSERT
  TO authenticated
  WITH CHECK (captain_id = auth.uid());

CREATE POLICY "teams captain delete"
  ON public.teams FOR DELETE
  TO authenticated
  USING (captain_id = auth.uid());
