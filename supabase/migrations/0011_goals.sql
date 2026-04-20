-- 0011_goals.sql — 进球记录 + 赛事射手榜视图

create table if not exists public.goals (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  scorer_id uuid references public.profiles(id) on delete set null,
  scorer_name text,
  assist_id uuid references public.profiles(id) on delete set null,
  minute int,
  is_own_goal boolean not null default false,
  is_penalty boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists goals_match_idx on public.goals(match_id);

alter table public.goals enable row level security;

drop policy if exists goals_public_read on public.goals;
create policy goals_public_read on public.goals for select using (true);

drop policy if exists goals_organizer_write on public.goals;
create policy goals_organizer_write on public.goals for insert with check (
  auth.uid() in (
    select e.creator_id from public.events e
    join public.matches m on m.event_id = e.id
    where m.id = goals.match_id
  )
);

drop policy if exists goals_organizer_delete on public.goals;
create policy goals_organizer_delete on public.goals for delete using (
  auth.uid() in (
    select e.creator_id from public.events e
    join public.matches m on m.event_id = e.id
    where m.id = goals.match_id
  )
);

-- 赛事射手榜视图（按进球数降序，点球/常规球均计数，乌龙不计入个人进球）
create or replace view public.event_scorers as
  select m.event_id,
         g.scorer_id,
         coalesce(p.name, g.scorer_name) as name,
         count(*) filter (where not g.is_own_goal) as goals,
         count(distinct g.match_id) as matches
  from public.goals g
  join public.matches m on m.id = g.match_id
  left join public.profiles p on p.id = g.scorer_id
  group by m.event_id, g.scorer_id, p.name, g.scorer_name;
