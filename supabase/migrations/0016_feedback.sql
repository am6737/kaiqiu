-- 0016_feedback.sql — 用户反馈（仅自写，读取走 admin / service_role）

create table if not exists public.feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  body text not null,
  contact text,
  status text not null default 'new' check (status in ('new','seen','resolved')),
  created_at timestamptz not null default now()
);
create index if not exists feedback_user_idx on public.feedback(user_id);

alter table public.feedback enable row level security;

drop policy if exists feedback_self_insert on public.feedback;
create policy feedback_self_insert on public.feedback for insert
  with check (auth.uid() = user_id);

drop policy if exists feedback_self_read on public.feedback;
create policy feedback_self_read on public.feedback for select
  using (auth.uid() = user_id);

-- 普通用户无法 update/delete，也无法读取他人反馈
