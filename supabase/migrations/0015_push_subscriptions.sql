-- 0015_push_subscriptions.sql — FCM/APNs 设备 token 注册表

create table if not exists public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  token text not null,
  platform text not null check (platform in ('ios', 'android', 'web')),
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (user_id, token)
);
create index if not exists push_user_idx on public.push_subscriptions(user_id);

alter table public.push_subscriptions enable row level security;

drop policy if exists push_self_all on public.push_subscriptions;
create policy push_self_all on public.push_subscriptions for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
