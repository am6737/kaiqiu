-- followers_list — 返回关注某用户的所有用户名
create or replace function public.followers_list(target_name text)
returns table(follower_name text)
language sql
stable
security definer
set search_path = ''
as $$
  select p.name
  from public.favorites f
  join public.profiles p on p.id = f.user_id
  where f.entity_type = 'user'
    and f.entity_id = target_name
  order by f.created_at desc;
$$;
