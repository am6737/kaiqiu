-- 0002_pickups.sql — 约球 + 阵型位置 (idempotent, safe to re-run)
--
-- Note: "almost full" status is derived client-side from filled/total ratio,
-- so we don't need a DB trigger to auto-update pickups.status. Keeps the
-- migration simpler and avoids Supabase SQL Editor's parser quirks.

-- ─────────────────────────────────────────────────────────────
-- Clean slate for re-runs
-- ─────────────────────────────────────────────────────────────
drop table if exists pickup_slots cascade;
drop table if exists pickups cascade;

-- ─────────────────────────────────────────────────────────────
-- pickups
-- ─────────────────────────────────────────────────────────────
create table pickups (
  id uuid primary key default gen_random_uuid(),
  host_id uuid references profiles on delete cascade,
  venue text not null,
  lat double precision,
  lng double precision,
  start_at timestamptz not null,
  duration_min int default 120,
  total int not null,                   -- 总人数 (10/12/...)
  level text,                           -- 初级/中级/高级
  fee_cents int default 0,              -- 费用（分，避免浮点）
  formation text default '4-3-3',
  field_type text,                      -- 天然草/人工草/室内
  status text default 'open',           -- open/almost/full/done (host-controlled)
  created_at timestamptz default now()
);

create index pickups_start_at_idx on pickups (start_at);
create index pickups_status_idx on pickups (status);
create index pickups_latlng_idx on pickups (lat, lng);

alter table pickups enable row level security;
create policy "pickups public read" on pickups for select using (true);
create policy "pickups host write" on pickups for all using (auth.uid() = host_id);

-- ─────────────────────────────────────────────────────────────
-- pickup_slots — one row per formation position
-- ─────────────────────────────────────────────────────────────
create table pickup_slots (
  id uuid primary key default gen_random_uuid(),
  pickup_id uuid references pickups on delete cascade,
  user_id uuid references profiles,
  position text,                        -- CF/GK/LB/CB/RB/CM/LW/ST/RW
  x int,                                -- 0-100 on formation grid
  y int,                                -- 0-100
  joined_at timestamptz default now(),
  unique (pickup_id, position, x, y)
);

create index pickup_slots_pickup_idx on pickup_slots (pickup_id);

alter table pickup_slots enable row level security;
create policy "slots public read" on pickup_slots for select using (true);
create policy "slots self join" on pickup_slots for insert with check (auth.uid() = user_id);
create policy "slots self leave" on pickup_slots for delete using (auth.uid() = user_id);
