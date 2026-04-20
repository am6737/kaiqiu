-- 0012_predictions.sql — 世界杯竞猜（match_id 使用字符串以兼容外部赛事编码）

create table if not exists public.predictions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  match_id text not null,
  choice text not null check (choice in ('A', 'draw', 'B')),
  stake int not null default 0,
  settled_at timestamptz,
  payout int,
  created_at timestamptz not null default now(),
  unique (user_id, match_id)
);
create index if not exists predictions_match_idx on public.predictions(match_id);

alter table public.predictions enable row level security;

drop policy if exists predictions_public_read on public.predictions;
create policy predictions_public_read on public.predictions for select using (true);

drop policy if exists predictions_self_write on public.predictions;
create policy predictions_self_write on public.predictions for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- 投票分布视图：给前端展示柱状图
create or replace view public.prediction_distribution as
  select match_id, choice, count(*) as votes, sum(stake) as total_stake
  from public.predictions
  group by match_id, choice;
