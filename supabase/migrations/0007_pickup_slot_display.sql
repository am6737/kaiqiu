-- 0007_pickup_slot_display.sql — let seed slots carry a display name
--
-- Our schema has pickup_slots.user_id FK to profiles, which requires a
-- real auth.users row. For demo seed data we want names like "老王" without
-- minting fake auth users, so we add a nullable display_name column.
--
-- Client shows `display_name` if present, otherwise looks up user_id.

alter table pickup_slots
  add column if not exists display_name text;
