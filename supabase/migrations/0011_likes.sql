-- 0011_likes.sql — Universal likes table for posts & articles

-- 1. likes table
create table likes (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  target_type text not null check (target_type in ('post', 'article')),
  target_id   uuid not null,
  created_at  timestamptz not null default now(),
  unique (user_id, target_type, target_id)
);

create index idx_likes_target on likes(target_type, target_id);

-- 2. RLS
alter table likes enable row level security;

create policy "Anyone can read likes"
  on likes for select using (true);

create policy "Authenticated users can insert own likes"
  on likes for insert
  with check (auth.uid() = user_id);

create policy "Users can delete own likes"
  on likes for delete
  using (auth.uid() = user_id);

-- 3. Add likes column to articles (posts already has one)
alter table articles add column if not exists likes int not null default 0;

-- 4. Unified trigger to keep posts.likes and articles.likes in sync
create or replace function sync_likes_count() returns trigger as $$
begin
  if tg_op = 'INSERT' then
    if new.target_type = 'post' then
      update posts set likes = likes + 1 where id = new.target_id;
    elsif new.target_type = 'article' then
      update articles set likes = likes + 1 where id = new.target_id;
    end if;
  elsif tg_op = 'DELETE' then
    if old.target_type = 'post' then
      update posts set likes = greatest(likes - 1, 0) where id = old.target_id;
    elsif old.target_type = 'article' then
      update articles set likes = greatest(likes - 1, 0) where id = old.target_id;
    end if;
  end if;
  return null;
end;
$$ language plpgsql security definer;

create trigger trg_sync_likes
  after insert or delete on likes
  for each row execute function sync_likes_count();
