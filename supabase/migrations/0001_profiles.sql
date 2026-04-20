-- 0001_profiles.sql — 用户档案 & 信用分
-- Run this in Supabase SQL Editor (https://supabase.com/dashboard → SQL Editor)

create table profiles (
  id uuid primary key references auth.users on delete cascade,
  name text not null,
  handle text unique,
  city text,
  district text,
  position text,               -- CF / GK / LB ...
  height int,
  foot text,
  credit int default 60,       -- 信用分
  avatar_url text,
  created_at timestamptz default now()
);

alter table profiles enable row level security;

create policy "profiles public read" on profiles for select using (true);
create policy "profiles self update" on profiles for update using (auth.uid() = id);

-- 新用户注册时自动建 profile
create or replace function handle_new_user() returns trigger language plpgsql security definer as $$
begin
  insert into profiles (id, name)
  values (new.id, coalesce(new.raw_user_meta_data->>'name', '新球友'));
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();
