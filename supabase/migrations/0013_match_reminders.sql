-- 0013_match_reminders.sql — 比赛提醒（给 S4 推送扫描使用）

create table if not exists public.match_reminders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  match_id text not null,
  remind_at timestamptz not null,
  sent_at timestamptz,
  created_at timestamptz not null default now(),
  unique (user_id, match_id)
);

-- 只索引尚未发送的提醒，加快 pg_cron 扫描
create index if not exists reminders_due_idx
  on public.match_reminders(remind_at) where sent_at is null;

alter table public.match_reminders enable row level security;

drop policy if exists reminders_self_all on public.match_reminders;
create policy reminders_self_all on public.match_reminders for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
