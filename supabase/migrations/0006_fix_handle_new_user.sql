-- 0006_fix_handle_new_user.sql — fix "Database error creating anonymous user".
--
-- Root causes:
--   1. SECURITY DEFINER functions need an explicit search_path or Postgres
--      can't find `public.profiles` — inserts fail silently, Supabase Auth
--      then reports a generic DB error.
--   2. If the trigger errors for any reason (e.g. NULL constraint, unique
--      conflict on re-sign-in), we'd rather the auth.users row still get
--      created. Wrap the insert in an exception handler so sign-in is
--      never blocked by profile creation.

create or replace function public.handle_new_user()
  returns trigger
  language plpgsql
  security definer
  set search_path = public
as $$
begin
  insert into public.profiles (id, name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', '新球友')
  );
  return new;
exception when others then
  -- Swallow: better a missing profile row than a broken sign-in.
  -- The client can upsert into profiles on first load if needed.
  return new;
end;
$$;

-- Trigger itself is already in place from 0001; no need to recreate it.
