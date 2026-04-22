-- 0001_schema.sql — 球局 app 完整 schema（greenfield，无历史兼容）
--
-- 每个 section 顶部先 drop 再 create，整个文件 paste 进 Supabase Dashboard
-- SQL Editor 即可起一个全新空库。
--
-- Section 顺序按 FK 依赖编排：
--   1. profiles          — 用户档案（被几乎所有表引用）
--   2. pickups           — 约球 + pickup_slots
--   3. events/matches    — 赛事、队伍、比赛、评分 + 视图
--   4. goals             — 进球记录 + 射手榜视图（依赖 matches）
--   5. messaging         — 会话、消息、Realtime + ensure_demo_conversation
--   6. user_teams        — 用户自建球队（与 events.teams 独立）
--   7. predictions       — 世界杯竞猜 + 分布视图
--   8. match_reminders   — 赛事提醒（pg_cron 扫描用）
--   9. favorites         — 统一收藏表
--  10. push_subscriptions — FCM/APNs 设备 token
--  11. feedback          — 用户反馈
--  12. storage_policies  — Supabase Storage RLS（需先在 Dashboard 建 bucket）
--  13. posts             — 社交动态（Feed post）
--  14. external_matches  — 外部赛事（世界杯、欧冠等）
--  15. match_participants— 比赛双方球员名单
--  16. player_*          — 球员属性 / 荣誉 / 统计视图
--  17. my_teammates      — 队友视图 + 比赛历史 RPC
--  18. notifications     — 站内通知
--  19. event_teams_count — 赛事报名队数视图
--  20. hot_tags          — 热门搜索标签
--  21. rating_likes      — 评分评论点赞
--
-- 附录 · 未启用的 cron 脚本见文件末尾注释块。


-- ═══════════════════════════════════════════════════════════════
-- 1. profiles — 用户档案 & 新用户 trigger
-- ═══════════════════════════════════════════════════════════════

drop trigger if exists on_auth_user_created on auth.users;
drop function if exists public.handle_new_user();
drop table if exists public.profiles cascade;

create table public.profiles (
  id uuid primary key references auth.users on delete cascade,
  name text not null,
  handle text unique,
  city text,
  district text,
  position text,                        -- CF / GK / LB ...
  height int,
  foot text,
  avatar_url text,
  created_at timestamptz default now()
);

alter table public.profiles enable row level security;
create policy "profiles public read" on public.profiles for select using (true);
create policy "profiles self update" on public.profiles for update using (auth.uid() = id);

-- handle_new_user: SECURITY DEFINER 必须设 search_path，否则找不到 public.profiles；
-- insert 用 on conflict 保证幂等（重复触发或手动 backfill 后不会报错）；
-- 外层再兜一次 exception，防止 profile 创建意外阻塞 auth.users 的注册流程。
create function public.handle_new_user()
  returns trigger
  language plpgsql
  security definer
  set search_path = public
as $$
begin
  insert into public.profiles (id, name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', '新球友')
  )
  on conflict (id) do nothing;
  return new;
exception when others then
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- ═══════════════════════════════════════════════════════════════
-- 2. pickups — 约球 + 阵型 slot
--    status (open/almost/full/done) 由 host 手动设置；客户端按 filled/total
--    比例推导 "almost full" 显示，不依赖 DB trigger。
-- ═══════════════════════════════════════════════════════════════

drop table if exists public.pickup_slots cascade;
drop table if exists public.pickups cascade;

create table public.pickups (
  id uuid primary key default gen_random_uuid(),
  host_id uuid references public.profiles on delete cascade,
  venue text not null,
  address text,                         -- 街道级详细地址（外部地图 URL scheme 用）
  venue_photo_url text,                 -- 场地照片
  lat double precision,
  lng double precision,
  start_at timestamptz not null,
  duration_min int default 120,
  total int not null,                   -- 总人数 (10/12/...)
  level text,                           -- 初级/中级/高级
  fee_cents int default 0,              -- 费用（分，避免浮点）
  formation text default '4-3-3',
  field_type text,                      -- 天然草/人工草/室内
  status text default 'open',           -- open/almost/full/done
  host_name text,                       -- demo 模式下直接展示的主办人名
  time_label text,                      -- demo 模式下直接展示的时间文案 "今晚 19:30"
  need int,                             -- demo 模式下直接展示的 "缺 N 人"
  created_at timestamptz default now()
);

create index pickups_start_at_idx on public.pickups (start_at);
create index pickups_status_idx on public.pickups (status);
create index pickups_latlng_idx on public.pickups (lat, lng);

alter table public.pickups enable row level security;
create policy "pickups public read" on public.pickups for select using (true);
create policy "pickups host write" on public.pickups for all using (auth.uid() = host_id);

create table public.pickup_slots (
  id uuid primary key default gen_random_uuid(),
  pickup_id uuid references public.pickups on delete cascade,
  user_id uuid references public.profiles,
  display_name text,                    -- 允许 demo 位置无真实 user（FK=null）
  position text,                        -- CF/GK/LB/CB/RB/CM/LW/ST/RW
  x int,                                -- 0-100 on formation grid
  y int,
  joined_at timestamptz default now(),
  unique (pickup_id, position, x, y)
);

create index pickup_slots_pickup_idx on public.pickup_slots (pickup_id);

alter table public.pickup_slots enable row level security;
create policy "slots public read" on public.pickup_slots for select using (true);
create policy "slots self join" on public.pickup_slots for insert with check (auth.uid() = user_id);
create policy "slots self leave" on public.pickup_slots for delete using (auth.uid() = user_id);


-- ═══════════════════════════════════════════════════════════════
-- 3. events / teams / matches / ratings — 赛事 + 虎扑式评分
-- ═══════════════════════════════════════════════════════════════

drop view if exists public.event_player_ratings;
drop view if exists public.player_rating_summary;
drop table if exists public.ratings cascade;
drop table if exists public.matches cascade;
drop table if exists public.teams cascade;
drop table if exists public.events cascade;

create table public.events (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid references public.profiles,
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

alter table public.events enable row level security;
create policy "events public read" on public.events for select using (true);
create policy "events creator write" on public.events for all using (auth.uid() = creator_id);

create table public.teams (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references public.events on delete cascade,
  name text not null,
  captain_id uuid references public.profiles,
  logo_url text,
  approved boolean default false,
  created_at timestamptz default now()
);

alter table public.teams enable row level security;
create policy "teams public read" on public.teams for select using (true);

create table public.matches (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references public.events on delete cascade,
  round text,                           -- qf/sf/final/group/league
  team_a_id uuid references public.teams,
  team_b_id uuid references public.teams,
  team_a_label text,                    -- fallback if team not in system
  team_b_label text,
  score_a int,
  score_b int,
  pk_score text,                        -- '4-3' if penalties
  played_at timestamptz,
  done boolean default false,
  is_live boolean default false,
  minute text,
  viewers int default 0,
  poster_url text
);

create index matches_event_idx on public.matches (event_id);
create index matches_live_idx on public.matches(is_live) where is_live = true;
alter table public.matches enable row level security;
create policy "matches public read" on public.matches for select using (true);

-- ratings: ratee_id nullable（demo 模式下被评价者无真实 auth.users）；
-- ratings_demo_unique 在 ratee_id 为 null 时用 ratee_name 做去重，
-- 因为 unique(match_id, rater_id, ratee_id) 里 NULL 互不相等不会去重。
create table public.ratings (
  id uuid primary key default gen_random_uuid(),
  match_id uuid references public.matches on delete cascade,
  rater_id uuid references public.profiles on delete cascade,
  ratee_id uuid references public.profiles on delete cascade,
  ratee_name text,
  score numeric(3,1) check (score between 0 and 10),
  comment text,
  highlight text,                       -- "2球1助" / "3次关键扑救"
  created_at timestamptz default now(),
  unique (match_id, rater_id, ratee_id)
);

create index ratings_ratee_idx on public.ratings (ratee_id);
create index ratings_match_idx on public.ratings (match_id);
create unique index ratings_demo_unique
  on public.ratings (match_id, rater_id, ratee_name)
  where ratee_id is null;

alter table public.ratings enable row level security;
create policy "ratings public read" on public.ratings for select using (true);
create policy "ratings self write" on public.ratings for insert with check (auth.uid() = rater_id);
create policy "ratings self update" on public.ratings for update using (auth.uid() = rater_id);

create view public.event_player_ratings as
select
  m.event_id,
  r.ratee_id,
  round(avg(r.score)::numeric, 2) as avg_score,
  count(*) as votes
from public.ratings r
join public.matches m on m.id = r.match_id
group by m.event_id, r.ratee_id;

create view public.player_rating_summary as
select
  ratee_id,
  round(avg(score)::numeric, 2) as avg_score,
  count(*) as votes
from public.ratings
group by ratee_id;


-- ═══════════════════════════════════════════════════════════════
-- 4. goals — 进球记录 + 射手榜视图（乌龙不计入个人进球）
-- ═══════════════════════════════════════════════════════════════

drop view if exists public.event_scorers;
drop table if exists public.goals cascade;

create table public.goals (
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

create index goals_match_idx on public.goals(match_id);

alter table public.goals enable row level security;

create policy goals_public_read on public.goals for select using (true);

create policy goals_organizer_write on public.goals for insert with check (
  auth.uid() in (
    select e.creator_id from public.events e
    join public.matches m on m.event_id = e.id
    where m.id = goals.match_id
  )
);

create policy goals_organizer_delete on public.goals for delete using (
  auth.uid() in (
    select e.creator_id from public.events e
    join public.matches m on m.event_id = e.id
    where m.id = goals.match_id
  )
);

create view public.event_scorers as
  select m.event_id,
         g.scorer_id,
         coalesce(p.name, g.scorer_name) as name,
         count(*) filter (where not g.is_own_goal) as goals,
         count(distinct g.match_id) as matches
  from public.goals g
  join public.matches m on m.id = g.match_id
  left join public.profiles p on p.id = g.scorer_id
  group by m.event_id, g.scorer_id, p.name, g.scorer_name;


-- ═══════════════════════════════════════════════════════════════
-- 5. messaging — 会话 + 消息 + Realtime + ensure_demo_conversation()
-- ═══════════════════════════════════════════════════════════════

drop function if exists public.ensure_demo_conversation();
drop function if exists public.ensure_event_conversation(text);
drop trigger if exists message_created on public.messages;
drop function if exists public.on_message_created();
drop table if exists public.messages cascade;
drop table if exists public.conversation_members cascade;
drop table if exists public.conversations cascade;

create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  kind text default 'dm',               -- dm / group / team
  title text,                           -- for groups
  updated_at timestamptz default now()
);

create table public.conversation_members (
  conv_id uuid references public.conversations on delete cascade,
  user_id uuid references public.profiles on delete cascade,
  unread int default 0,
  last_read_at timestamptz default now(),
  primary key (conv_id, user_id)
);

alter table public.conversations enable row level security;

create policy "conversations member read" on public.conversations for select using (
  exists (
    select 1 from public.conversation_members m
    where m.conv_id = conversations.id and m.user_id = auth.uid()
  )
);
create policy "conversations authenticated insert" on public.conversations
  for insert with check (auth.uid() is not null);
create policy "conversations member update" on public.conversations for update using (
  exists (
    select 1 from public.conversation_members m
    where m.conv_id = conversations.id and m.user_id = auth.uid()
  )
);
create policy "conversations member delete" on public.conversations for delete using (
  exists (
    select 1 from public.conversation_members m
    where m.conv_id = conversations.id and m.user_id = auth.uid()
  )
);

alter table public.conversation_members enable row level security;
create policy "members self read" on public.conversation_members for select using (user_id = auth.uid());
create policy "members self insert" on public.conversation_members for insert with check (user_id = auth.uid());
create policy "members self update" on public.conversation_members for update using (user_id = auth.uid());
create policy "members self delete" on public.conversation_members for delete using (user_id = auth.uid());

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conv_id uuid references public.conversations on delete cascade,
  sender_id uuid references public.profiles,
  body text,
  kind text default 'text',             -- text / image / system
  created_at timestamptz default now()
);

create index messages_conv_idx on public.messages (conv_id, created_at desc);

alter table public.messages enable row level security;

create policy "messages member read" on public.messages for select using (
  exists (
    select 1 from public.conversation_members m
    where m.conv_id = messages.conv_id and m.user_id = auth.uid()
  )
);

create policy "messages member write" on public.messages for insert with check (
  sender_id = auth.uid()
  and exists (
    select 1 from public.conversation_members m
    where m.conv_id = messages.conv_id and m.user_id = auth.uid()
  )
);

create function public.on_message_created() returns trigger language plpgsql as $$
begin
  update public.conversations set updated_at = now() where id = new.conv_id;
  update public.conversation_members
    set unread = unread + 1
    where conv_id = new.conv_id and user_id != new.sender_id;
  return new;
end;
$$;

create trigger message_created
  after insert on public.messages
  for each row execute function public.on_message_created();

-- Realtime 订阅（新消息推送）
alter publication supabase_realtime add table public.messages;

-- ensure_demo_conversation: 每个匿名用户首次打开 Messages tab 时调用 rpc，
-- 已在任意会话里则 no-op 返回现有 conv_id，否则建 "球局 · 新手大厅" + 欢迎消息。
create function public.ensure_demo_conversation()
  returns uuid
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_conv uuid;
begin
  if v_user is null then
    raise exception 'Not authenticated';
  end if;

  -- 自愈：handle_new_user trigger 可能漏掉的孤儿用户在此补齐 profile，
  -- 避免后续 insert conversation_members 时触发 FK 约束失败。
  insert into profiles (id, name)
  select u.id, coalesce(u.raw_user_meta_data->>'name', '新球友')
  from auth.users u
  where u.id = v_user
  on conflict (id) do nothing;

  select conv_id into v_conv
    from conversation_members
    where user_id = v_user
    limit 1;

  if v_conv is not null then
    return v_conv;
  end if;

  insert into conversations (kind, title)
  values ('group', '球局 · 新手大厅')
  returning id into v_conv;

  insert into conversation_members (conv_id, user_id, unread)
  values (v_conv, v_user, 0);

  insert into messages (conv_id, sender_id, body, kind)
  values (v_conv, null, '欢迎来到球局 · 新手大厅。这里是测试聊天室，随便发条消息试试。', 'system');

  return v_conv;
end;
$$;

grant execute on function public.ensure_demo_conversation() to authenticated, anon;

-- ensure_event_conversation: 打开赛事讨论 tab 时调用；
-- 原子地查找或创建 title='event:{id}' 的群组会话，并保证当前用户是成员。
create function public.ensure_event_conversation(p_event_id text)
  returns uuid
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_title text := 'event:' || p_event_id;
  v_conv uuid;
begin
  if v_user is null then
    raise exception 'Not authenticated';
  end if;

  -- 自愈：见 ensure_demo_conversation 的同段注释。
  insert into profiles (id, name)
  select u.id, coalesce(u.raw_user_meta_data->>'name', '新球友')
  from auth.users u
  where u.id = v_user
  on conflict (id) do nothing;

  select id into v_conv from conversations where title = v_title limit 1;

  if v_conv is null then
    insert into conversations (kind, title)
    values ('group', v_title)
    returning id into v_conv;
  end if;

  insert into conversation_members (conv_id, user_id, unread)
  values (v_conv, v_user, 0)
  on conflict (conv_id, user_id) do nothing;

  return v_conv;
end;
$$;

grant execute on function public.ensure_event_conversation(text) to authenticated;

-- ensure_dm_conversation: 1v1 DM 的幂等"找到或创建"RPC。
-- 并发 tradeoff：conversations 表上不存在"(DM 双方) 唯一键"约束，
-- 严格幂等只在串行调用下成立；发生概率极低，读方以 RPC 返回 id 为准。

drop function if exists public.ensure_dm_conversation(uuid);

create function public.ensure_dm_conversation(p_other_user_id uuid)
  returns uuid
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_id uuid;
begin
  if v_me is null then
    raise exception 'not_authenticated';
  end if;
  if p_other_user_id is null then
    raise exception 'other_required';
  end if;
  if p_other_user_id = v_me then
    raise exception 'cannot_dm_self';
  end if;
  if not exists (select 1 from profiles where id = p_other_user_id) then
    raise exception 'user_not_found';
  end if;

  select c.id into v_id
  from conversations c
  where c.kind = 'dm'
    and exists (select 1 from conversation_members m
                where m.conv_id = c.id and m.user_id = v_me)
    and exists (select 1 from conversation_members m
                where m.conv_id = c.id and m.user_id = p_other_user_id)
    and (select count(*) from conversation_members m
         where m.conv_id = c.id) = 2
  limit 1;

  if v_id is not null then
    return v_id;
  end if;

  insert into conversations (kind) values ('dm') returning id into v_id;

  insert into conversation_members (conv_id, user_id, unread)
  values (v_id, v_me, 0), (v_id, p_other_user_id, 0);

  return v_id;
end;
$$;

grant execute on function public.ensure_dm_conversation(uuid) to authenticated;

-- v_conversation_peers: DM 会话成员视图，供客户端查对端 uid。
create or replace view public.v_conversation_peers as
select m.conv_id as conv_id,
       m.user_id as peer_user_id
from conversation_members m
join conversations c on c.id = m.conv_id
where c.kind = 'dm'
  and exists (
    select 1 from conversation_members me
    where me.conv_id = m.conv_id and me.user_id = auth.uid()
  );

grant select on public.v_conversation_peers to authenticated;


-- ═══════════════════════════════════════════════════════════════
-- 6. user_teams — 用户自建球队（与 events.teams 独立，不绑定赛事）
-- ═══════════════════════════════════════════════════════════════

drop table if exists public.user_team_members cascade;
drop table if exists public.user_teams cascade;

create table public.user_teams (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  city text,
  sub text,
  created_at timestamptz not null default now()
);

create table public.user_team_members (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.user_teams(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member',
  joined_at timestamptz not null default now(),
  unique (team_id, user_id)
);

create index user_team_members_team_idx on public.user_team_members(team_id);
create index user_team_members_user_idx on public.user_team_members(user_id);

alter table public.user_teams enable row level security;
alter table public.user_team_members enable row level security;

create policy user_teams_public_read on public.user_teams for select using (true);
create policy user_teams_owner_write on public.user_teams for all
  using (auth.uid() = owner_id) with check (auth.uid() = owner_id);

create policy user_team_members_public_read on public.user_team_members for select using (true);
create policy user_team_members_self_join on public.user_team_members for insert
  with check (auth.uid() = user_id);
create policy user_team_members_self_leave on public.user_team_members for delete
  using (auth.uid() = user_id);


-- ═══════════════════════════════════════════════════════════════
-- 7. predictions — 世界杯竞猜（match_id 为 text 以兼容外部赛事编码）
-- ═══════════════════════════════════════════════════════════════

drop view if exists public.prediction_distribution;
drop table if exists public.predictions cascade;

create table public.predictions (
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

create index predictions_match_idx on public.predictions(match_id);

alter table public.predictions enable row level security;

create policy predictions_public_read on public.predictions for select using (true);
create policy predictions_self_write on public.predictions for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

create view public.prediction_distribution as
  select match_id, choice, count(*) as votes, sum(stake) as total_stake
  from public.predictions
  group by match_id, choice;


-- ═══════════════════════════════════════════════════════════════
-- 8. match_reminders — 赛事提醒（pg_cron 每分钟扫描未发送项）
-- ═══════════════════════════════════════════════════════════════

drop table if exists public.match_reminders cascade;

create table public.match_reminders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  match_id text not null,
  remind_at timestamptz not null,
  sent_at timestamptz,
  created_at timestamptz not null default now(),
  unique (user_id, match_id)
);

-- 仅索引未发送项，加快 cron 扫描
create index reminders_due_idx
  on public.match_reminders(remind_at) where sent_at is null;

alter table public.match_reminders enable row level security;

create policy reminders_self_all on public.match_reminders for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);


-- ═══════════════════════════════════════════════════════════════
-- 9. favorites — 统一收藏表（约球 / 赛事 / 用户）
-- ═══════════════════════════════════════════════════════════════

drop table if exists public.favorites cascade;

create table public.favorites (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  entity_type text not null check (entity_type in ('pickup', 'event', 'user')),
  entity_id text not null,
  created_at timestamptz not null default now(),
  unique (user_id, entity_type, entity_id)
);

create index favorites_user_idx on public.favorites(user_id, entity_type);

alter table public.favorites enable row level security;

create policy favorites_self_all on public.favorites for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);


-- ═══════════════════════════════════════════════════════════════
-- 10. push_subscriptions — FCM/APNs 设备 token 注册表
-- ═══════════════════════════════════════════════════════════════

drop table if exists public.push_subscriptions cascade;

create table public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  token text not null,
  platform text not null check (platform in ('ios', 'android', 'web')),
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (user_id, token)
);

create index push_user_idx on public.push_subscriptions(user_id);

alter table public.push_subscriptions enable row level security;

create policy push_self_all on public.push_subscriptions for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);


-- ═══════════════════════════════════════════════════════════════
-- 11. feedback — 用户反馈（仅自写自读，读取他人走 service_role）
-- ═══════════════════════════════════════════════════════════════

drop table if exists public.feedback cascade;

create table public.feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  body text not null,
  contact text,
  status text not null default 'new' check (status in ('new','seen','resolved')),
  created_at timestamptz not null default now()
);

create index feedback_user_idx on public.feedback(user_id);

alter table public.feedback enable row level security;

create policy feedback_self_insert on public.feedback for insert
  with check (auth.uid() = user_id);

create policy feedback_self_read on public.feedback for select
  using (auth.uid() = user_id);


-- ═══════════════════════════════════════════════════════════════
-- 12. storage_policies — Supabase Storage RLS
--     先在 Dashboard → Storage 建 3 个 public bucket：
--       avatars / event-covers / pickup-photos
--     规则：任何人读，用户只能写 / 改 / 删以自己 uid 为前缀的路径
-- ═══════════════════════════════════════════════════════════════

drop policy if exists "avatars_public_read" on storage.objects;
create policy "avatars_public_read" on storage.objects
  for select using (bucket_id = 'avatars');

drop policy if exists "avatars_self_write" on storage.objects;
create policy "avatars_self_write" on storage.objects
  for insert with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "avatars_self_update" on storage.objects;
create policy "avatars_self_update" on storage.objects
  for update using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "avatars_self_delete" on storage.objects;
create policy "avatars_self_delete" on storage.objects
  for delete using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "event_covers_public_read" on storage.objects;
create policy "event_covers_public_read" on storage.objects
  for select using (bucket_id = 'event-covers');

drop policy if exists "event_covers_self_write" on storage.objects;
create policy "event_covers_self_write" on storage.objects
  for insert with check (
    bucket_id = 'event-covers'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "event_covers_self_update" on storage.objects;
create policy "event_covers_self_update" on storage.objects
  for update using (
    bucket_id = 'event-covers'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "pickup_photos_public_read" on storage.objects;
create policy "pickup_photos_public_read" on storage.objects
  for select using (bucket_id = 'pickup-photos');

drop policy if exists "pickup_photos_self_write" on storage.objects;
create policy "pickup_photos_self_write" on storage.objects
  for insert with check (
    bucket_id = 'pickup-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "pickup_photos_self_update" on storage.objects;
create policy "pickup_photos_self_update" on storage.objects
  for update using (
    bucket_id = 'pickup-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );


-- ═══════════════════════════════════════════════════════════════
-- 13. posts — 社交动态（Feed 中的 post 类型）
-- ═══════════════════════════════════════════════════════════════

drop table if exists public.posts cascade;

create table public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid references public.profiles on delete cascade,
  body text not null,
  tags text[] default '{}',
  likes int default 0,
  comments int default 0,
  shares int default 0,
  created_at timestamptz default now()
);

create index posts_created_idx on public.posts(created_at desc);

alter table public.posts enable row level security;
create policy "posts public read" on public.posts for select using (true);
create policy "posts self insert" on public.posts for insert
  with check (auth.uid() = author_id);
create policy "posts self update" on public.posts for update
  using (auth.uid() = author_id);
create policy "posts self delete" on public.posts for delete
  using (auth.uid() = author_id);


-- ═══════════════════════════════════════════════════════════════
-- 14. external_matches — 外部赛事（世界杯、欧冠等）
-- ═══════════════════════════════════════════════════════════════

drop table if exists public.external_matches cascade;

create table public.external_matches (
  id uuid primary key default gen_random_uuid(),
  team_a text not null,
  team_b text not null,
  flag_a text,
  flag_b text,
  competition text,
  kick_off timestamptz,
  is_live boolean default false,
  score_a int,
  score_b int,
  minute text,
  viewers int default 0,
  status text default 'upcoming',
  created_at timestamptz default now()
);

create index ext_matches_kickoff_idx on public.external_matches(kick_off desc);

alter table public.external_matches enable row level security;
create policy ext_read on public.external_matches for select using (true);


-- ═══════════════════════════════════════════════════════════════
-- 15. match_participants — 比赛双方球员名单
-- ═══════════════════════════════════════════════════════════════

drop table if exists public.match_participants cascade;

create table public.match_participants (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches on delete cascade,
  user_id uuid references public.profiles,
  display_name text not null,
  position text,
  side text not null check (side in ('a', 'b')),
  created_at timestamptz default now(),
  unique (match_id, user_id)
);

create index match_part_match_idx on public.match_participants(match_id);

alter table public.match_participants enable row level security;
create policy match_part_read on public.match_participants for select using (true);
create policy match_part_write on public.match_participants for insert
  with check (true);


-- ═══════════════════════════════════════════════════════════════
-- 16. player_attributes + player_honors + player_stats 视图
-- ═══════════════════════════════════════════════════════════════

drop table if exists public.player_attributes cascade;
drop table if exists public.player_honors cascade;
drop view if exists public.player_stats;

create table public.player_attributes (
  user_id uuid primary key references public.profiles on delete cascade,
  speed int default 50,
  shooting int default 50,
  passing int default 50,
  defense int default 50,
  stamina int default 50,
  technique int default 50,
  updated_at timestamptz default now()
);

alter table public.player_attributes enable row level security;
create policy attrs_read on public.player_attributes for select using (true);
create policy attrs_write on public.player_attributes for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

create table public.player_honors (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles on delete cascade,
  year text not null,
  title text not null,
  meta text,
  created_at timestamptz default now()
);

alter table public.player_honors enable row level security;
create policy honors_read on public.player_honors for select using (true);
create policy honors_write on public.player_honors for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

create or replace view public.player_stats as
select
  p.id as user_id,
  count(distinct r.match_id) as matches,
  coalesce(sum(case when g.scorer_id = p.id and not g.is_own_goal then 1 else 0 end), 0) as goals,
  coalesce(sum(case when g.assist_id = p.id then 1 else 0 end), 0) as assists
from public.profiles p
left join public.ratings r on r.ratee_id = p.id
left join public.goals g on g.match_id = r.match_id
  and (g.scorer_id = p.id or g.assist_id = p.id)
group by p.id;


-- ═══════════════════════════════════════════════════════════════
-- 17. my_teammates 视图 + my_match_history RPC
-- ═══════════════════════════════════════════════════════════════

create or replace view public.my_teammates as
select
  mine.user_id  as me,
  theirs.user_id as teammate_id,
  p.name         as teammate_name,
  p.avatar_url,
  count(distinct mine.pickup_id) as matches
from public.pickup_slots mine
join public.pickup_slots theirs
  on  theirs.pickup_id = mine.pickup_id
  and theirs.user_id != mine.user_id
  and theirs.user_id is not null
join public.profiles p on p.id = theirs.user_id
where mine.user_id is not null
group by mine.user_id, theirs.user_id, p.name, p.avatar_url;

create or replace function public.my_match_history(p_user_id uuid)
returns table (
  match_id uuid,
  played_at timestamptz,
  event_name text,
  team_a text,
  team_b text,
  score_a int,
  score_b int,
  my_goals bigint,
  my_assists bigint
) language sql stable as $$
  select
    m.id,
    m.played_at,
    e.name,
    coalesce(m.team_a_label, ''),
    coalesce(m.team_b_label, ''),
    coalesce(m.score_a, 0),
    coalesce(m.score_b, 0),
    count(*) filter (where g.scorer_id = p_user_id and not g.is_own_goal),
    count(*) filter (where g.assist_id = p_user_id)
  from public.matches m
  join public.events e on e.id = m.event_id
  join public.ratings r on r.match_id = m.id and r.ratee_id = p_user_id
  left join public.goals g on g.match_id = m.id
    and (g.scorer_id = p_user_id or g.assist_id = p_user_id)
  where m.done = true
  group by m.id, m.played_at, e.name
  order by m.played_at desc;
$$;

grant execute on function public.my_match_history(uuid) to authenticated;


-- ═══════════════════════════════════════════════════════════════
-- 18. notifications — 站内通知
-- ═══════════════════════════════════════════════════════════════

drop table if exists public.notifications cascade;

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles on delete cascade,
  type text not null default 'system',    -- system/rating/pickup/match/follow
  title text not null,
  body text not null,
  icon text,
  route text,
  read boolean default false,
  created_at timestamptz default now()
);

create index notif_user_created_idx
  on public.notifications(user_id, created_at desc);

alter table public.notifications enable row level security;

create policy notif_self_read on public.notifications
  for select using (auth.uid() = user_id);

create policy notif_self_update on public.notifications
  for update using (auth.uid() = user_id)
  with check (auth.uid() = user_id);


-- ═══════════════════════════════════════════════════════════════
-- 19. event_teams_count 视图
-- ═══════════════════════════════════════════════════════════════

create or replace view public.event_teams_count as
select
  e.id as event_id,
  count(t.id)::int as teams_registered
from public.events e
left join public.teams t on t.event_id = e.id
group by e.id;


-- ═══════════════════════════════════════════════════════════════
-- 20. hot_tags — 热门搜索标签（可后台维护）
-- ═══════════════════════════════════════════════════════════════

drop table if exists public.hot_tags cascade;

create table public.hot_tags (
  id serial primary key,
  label text not null unique,
  sort_order int default 0,
  active boolean default true,
  created_at timestamptz default now()
);

alter table public.hot_tags enable row level security;
create policy hot_tags_public_read on public.hot_tags
  for select using (true);

insert into public.hot_tags (label, sort_order) values
  ('足球', 1), ('篮球', 2), ('约球', 3), ('龙岗杯', 4),
  ('莲花山', 5), ('新手局', 6), ('中级', 7), ('免费场', 8);


-- ═══════════════════════════════════════════════════════════════
-- 21. rating_likes — 评分评论点赞
-- ═══════════════════════════════════════════════════════════════

drop table if exists public.rating_likes cascade;

create table public.rating_likes (
  rating_id uuid references public.ratings on delete cascade,
  user_id uuid references public.profiles on delete cascade,
  created_at timestamptz default now(),
  primary key (rating_id, user_id)
);

alter table public.rating_likes enable row level security;

create policy rating_likes_read on public.rating_likes
  for select using (true);
create policy rating_likes_self_write on public.rating_likes
  for all using (auth.uid() = user_id)
  with check (auth.uid() = user_id);


-- ═══════════════════════════════════════════════════════════════
-- 附录 · pg_cron 提醒扫描（未启用，按需手动执行）
--
-- 前置：Dashboard → Database → Extensions 启用 pg_cron + pg_net，
--       Edge Function `send_push` 已部署，<PROJECT_REF> 替换为真实值。
--
-- create extension if not exists pg_cron;
-- create extension if not exists pg_net;
--
-- select cron.schedule(
--   'send-match-reminders',
--   '* * * * *',
--   $$
--     with due as (
--       select user_id
--         from public.match_reminders
--        where sent_at is null and remind_at <= now()
--     )
--     select
--       net.http_post(
--         url := 'https://<PROJECT_REF>.functions.supabase.co/send_push',
--         headers := jsonb_build_object(
--           'content-type', 'application/json',
--           'authorization', 'Bearer ' ||
--             current_setting('app.settings.service_role_key', true)
--         ),
--         body := jsonb_build_object(
--           'user_ids', (select coalesce(array_agg(user_id), array[]::uuid[]) from due),
--           'title', '比赛即将开始',
--           'body', '你订阅的比赛 10 分钟后开赛',
--           'data', jsonb_build_object('route', '/worldcup')
--         )
--       ),
--       (update public.match_reminders
--          set sent_at = now()
--        where sent_at is null and remind_at <= now());
--   $$
-- );
-- ═══════════════════════════════════════════════════════════════
