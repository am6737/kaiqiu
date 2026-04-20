-- 0014_favorites.sql — 统一收藏表（约球 / 赛事 / 用户）

create table if not exists public.favorites (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  entity_type text not null check (entity_type in ('pickup', 'event', 'user')),
  entity_id text not null,
  created_at timestamptz not null default now(),
  unique (user_id, entity_type, entity_id)
);
create index if not exists favorites_user_idx on public.favorites(user_id, entity_type);

alter table public.favorites enable row level security;

drop policy if exists favorites_self_all on public.favorites;
create policy favorites_self_all on public.favorites for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
