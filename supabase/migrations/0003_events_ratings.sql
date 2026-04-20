-- 0003_events_ratings.sql — 赛事 + 比赛 + 虎扑式评分 (idempotent)

-- Clean slate for re-runs
drop view if exists event_player_ratings;
drop view if exists player_rating_summary;
drop table if exists ratings cascade;
drop table if exists matches cascade;
drop table if exists teams cascade;
drop table if exists events cascade;

create table events (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid references profiles,
  name text not null,
  sub text,
  city text,
  template text,                        -- knockout16/group8/wc/league
  team_size int default 11,
  teams_max int,
  prize_cents int,
  fee_cents int,
  deadline timestamptz,
  starts_at timestamptz,
  ends_at timestamptz,
  status text default 'registering',    -- registering/ongoing/done
  cover_url text,
  created_at timestamptz default now()
);

alter table events enable row level security;
create policy "events public read" on events for select using (true);
create policy "events creator write" on events for all using (auth.uid() = creator_id);

create table teams (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references events on delete cascade,
  name text not null,
  captain_id uuid references profiles,
  logo_url text,
  approved boolean default false,
  created_at timestamptz default now()
);

alter table teams enable row level security;
create policy "teams public read" on teams for select using (true);

create table matches (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references events on delete cascade,
  round text,                           -- qf/sf/final/group/league
  team_a_id uuid references teams,
  team_b_id uuid references teams,
  team_a_label text,                    -- fallback if team not in system
  team_b_label text,
  score_a int,
  score_b int,
  pk_score text,                        -- '4-3' if penalties
  played_at timestamptz,
  done boolean default false
);

create index matches_event_idx on matches (event_id);
alter table matches enable row level security;
create policy "matches public read" on matches for select using (true);

-- 虎扑式评分
create table ratings (
  id uuid primary key default gen_random_uuid(),
  match_id uuid references matches on delete cascade,
  rater_id uuid references profiles on delete cascade,
  ratee_id uuid references profiles on delete cascade,
  score numeric(3,1) check (score between 0 and 10),
  comment text,
  highlight text,                       -- "2球1助" / "3次关键扑救"
  created_at timestamptz default now(),
  unique (match_id, rater_id, ratee_id) -- 一人一场只能给同一人评一次
);

create index ratings_ratee_idx on ratings (ratee_id);
create index ratings_match_idx on ratings (match_id);

alter table ratings enable row level security;
create policy "ratings public read" on ratings for select using (true);
create policy "ratings self write" on ratings for insert with check (auth.uid() = rater_id);
create policy "ratings self update" on ratings for update using (auth.uid() = rater_id);

-- Aggregate view — avg score per player per event (for leaderboards)
create or replace view event_player_ratings as
select
  m.event_id,
  r.ratee_id,
  round(avg(r.score)::numeric, 2) as avg_score,
  count(*) as votes
from ratings r
join matches m on m.id = r.match_id
group by m.event_id, r.ratee_id;

-- All-time player rating summary
create or replace view player_rating_summary as
select
  ratee_id,
  round(avg(score)::numeric, 2) as avg_score,
  count(*) as votes
from ratings
group by ratee_id;
