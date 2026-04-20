-- 0010_user_teams.sql — 用户自建球队（"我的队伍"）
-- 与已存在的 teams（赛事参赛队，见 0003）不同：
-- user_teams 是用户个人持有的队伍，不绑定任何具体赛事。

create table if not exists public.user_teams (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  city text,
  sub text,
  created_at timestamptz not null default now()
);

create table if not exists public.user_team_members (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.user_teams(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member',
  joined_at timestamptz not null default now(),
  unique (team_id, user_id)
);

create index if not exists user_team_members_team_idx on public.user_team_members(team_id);
create index if not exists user_team_members_user_idx on public.user_team_members(user_id);

alter table public.user_teams enable row level security;
alter table public.user_team_members enable row level security;

drop policy if exists user_teams_public_read on public.user_teams;
create policy user_teams_public_read on public.user_teams for select using (true);

drop policy if exists user_teams_owner_write on public.user_teams;
create policy user_teams_owner_write on public.user_teams for all
  using (auth.uid() = owner_id) with check (auth.uid() = owner_id);

drop policy if exists user_team_members_public_read on public.user_team_members;
create policy user_team_members_public_read on public.user_team_members for select using (true);

drop policy if exists user_team_members_self_join on public.user_team_members;
create policy user_team_members_self_join on public.user_team_members for insert
  with check (auth.uid() = user_id);

drop policy if exists user_team_members_self_leave on public.user_team_members;
create policy user_team_members_self_leave on public.user_team_members for delete
  using (auth.uid() = user_id);
