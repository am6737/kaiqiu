-- Returns how many users have favorited (followed) the given entity_id
-- with entity_type = 'user'. Runs as SECURITY DEFINER so it can read
-- across all rows regardless of the caller's RLS scope.
create or replace function public.followers_count(target_name text)
returns bigint
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)
  from public.favorites
  where entity_type = 'user'
    and entity_id = target_name;
$$;
