-- Allow users to claim empty pickup slots (upsert sets user_id on rows where
-- user_id is currently null) and to update their own slots.
CREATE POLICY "slots self update"
  ON public.pickup_slots FOR UPDATE
  TO authenticated
  USING (user_id IS NULL OR user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
