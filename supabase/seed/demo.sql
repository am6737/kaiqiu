-- demo.sql — 完整 demo fixture
--   pickups + 阵型 + 赛事（16 队 + 15 场 bracket）+ 进球 + 评分 + 世界杯竞猜
--
-- Prereqs: migrations/0001_schema.sql 已应用。
-- Safe to re-run: 每个 section 先 DELETE 再 INSERT。
--
-- 与客户端的隐式约定：
--   - lib/providers.dart → demoMatchId = '22222222-2222-2222-2222-222222222222'
--   - lib/data/mock.dart 的 pickups/lineup 与本文件镜像
--   - 首场 pickup venue = '龙岗体育中心 3号场'（section 2 的 lineup 引用）
--   - 世界杯竞猜 match_id 用 'wc-focus'/'w1'..'w5'（lib/features/events/world_cup_screen.dart）

-- ═══════════════════════════════════════════════════════════════
-- 0. Demo profiles — 9 位出镜主力球员（评分 / 射手 / 进球明细）
--    写 auth.users 会触发 handle_new_user → 自动建 profiles 行，
--    再 UPDATE 回填 avatar_url / position / handle。
--    与 lib/data/demo_images.dart 的 playerAvatarByName 一一对应。
-- ═══════════════════════════════════════════════════════════════

-- 先清掉旧 demo 账号：profiles.id ON DELETE CASCADE 联动；
-- 同时级联清除 ratings（ratee_id cascade）/ goals.scorer_id 被 set null。
delete from auth.users where id in (
  '10000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000002',
  '10000000-0000-0000-0000-000000000003',
  '10000000-0000-0000-0000-000000000004',
  '10000000-0000-0000-0000-000000000005',
  '10000000-0000-0000-0000-000000000006',
  '10000000-0000-0000-0000-000000000007',
  '10000000-0000-0000-0000-000000000008',
  '10000000-0000-0000-0000-000000000009'
);

-- 写 auth.users 最小可用字段集：encrypted_password 用 crypt() 兜底非空，
-- raw_user_meta_data.name 交给 trigger 回灌 profiles.name。
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
)
select
  '00000000-0000-0000-0000-000000000000'::uuid,
  dp.id::uuid,
  'authenticated', 'authenticated',
  dp.email,
  crypt('demo-password', gen_salt('bf')),
  now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  jsonb_build_object('name', dp.name),
  now(), now()
from (values
  ('10000000-0000-0000-0000-000000000001', 'demo-chenzirui@qiuju.local', '陈子睿'),
  ('10000000-0000-0000-0000-000000000002', 'demo-laowang@qiuju.local',   '老王'),
  ('10000000-0000-0000-0000-000000000003', 'demo-xuzheng@qiuju.local',   '徐铮'),
  ('10000000-0000-0000-0000-000000000004', 'demo-linshuai@qiuju.local',  '林帅'),
  ('10000000-0000-0000-0000-000000000005', 'demo-jiangbei@qiuju.local',  '江北'),
  ('10000000-0000-0000-0000-000000000006', 'demo-kevin@qiuju.local',     'Kevin'),
  ('10000000-0000-0000-0000-000000000007', 'demo-coach@qiuju.local',     '张教练'),
  ('10000000-0000-0000-0000-000000000008', 'demo-xiaozhao@qiuju.local',  '小赵'),
  ('10000000-0000-0000-0000-000000000009', 'demo-aze@qiuju.local',       '阿泽')
) as dp(id, email, name);

-- 回填 avatar_url / position / handle（trigger 只给了 id+name）。
update public.profiles p set
  name = dp.name,
  position = dp.position,
  avatar_url = dp.avatar_url,
  handle = dp.handle
from (values
  ('10000000-0000-0000-0000-000000000001'::uuid, '陈子睿',   'ST', 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&h=400&q=70', 'demo-chenzirui'),
  ('10000000-0000-0000-0000-000000000002'::uuid, '老王',     'GK', 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?auto=format&fit=crop&w=400&h=400&q=70', 'demo-laowang'),
  ('10000000-0000-0000-0000-000000000003'::uuid, '徐铮',     'LW', 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=400&h=400&q=70', 'demo-xuzheng'),
  ('10000000-0000-0000-0000-000000000004'::uuid, '林帅',     'CM', 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?auto=format&fit=crop&w=400&h=400&q=70', 'demo-linshuai'),
  ('10000000-0000-0000-0000-000000000005'::uuid, '江北',     'CB', 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?auto=format&fit=crop&w=400&h=400&q=70', 'demo-jiangbei'),
  ('10000000-0000-0000-0000-000000000006'::uuid, 'Kevin',    'LB', 'https://images.unsplash.com/photo-1552058544-f2b08422138a?auto=format&fit=crop&w=400&h=400&q=70', 'demo-kevin'),
  ('10000000-0000-0000-0000-000000000007'::uuid, '张教练',   'CM', 'https://images.unsplash.com/photo-1531123897727-8f129e1688ce?auto=format&fit=crop&w=400&h=400&q=70', 'demo-coach'),
  ('10000000-0000-0000-0000-000000000008'::uuid, '小赵',     'CM', 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?auto=format&fit=crop&w=400&h=400&q=70', 'demo-xiaozhao'),
  ('10000000-0000-0000-0000-000000000009'::uuid, '阿泽',     'RB', 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=400&h=400&q=70', 'demo-aze')
) as dp(id, name, position, avatar_url, handle)
where p.id = dp.id;

-- ═══════════════════════════════════════════════════════════════
-- 1. Pickups — 6 场约球，坐标用 0-1 归一化后再映射到深圳经纬度窗口
-- ═══════════════════════════════════════════════════════════════

delete from pickup_slots where pickup_id in (
  select id from pickups where venue in (
    '龙岗体育中心 3号场',
    '大运公园足球场',
    '平湖体育公园',
    '坂田足球场',
    '华南城五人制',
    '大鹏海滨球场'
  )
);

delete from pickups where venue in (
  '龙岗体育中心 3号场',
  '大运公园足球场',
  '平湖体育公园',
  '坂田足球场',
  '华南城五人制',
  '大鹏海滨球场'
);

-- start_at uses relative dates so "今晚 19:30", "明天 07:00" stay meaningful.
-- The client still displays `time_label` directly, so these timestamps are
-- just for sort order.
insert into pickups (
  venue, host_name, time_label, need, total, level, fee_cents,
  duration_min, status, lat, lng, start_at, venue_photo_url
) values
  ('龙岗体育中心 3号场', '老王',    '今晚 19:30',   3, 10, '中级', 5000, 120, 'open',   0.40, 0.35, now() + interval '8 hours',
   'https://images.unsplash.com/photo-1529900748604-07564a03e7a6?auto=format&fit=crop&w=1200&h=600&q=70'),
  ('大运公园足球场',    'Kevin',   '明天 07:00',   1, 12, '高级', 4000,  90, 'almost', 0.60, 0.50, now() + interval '1 day',
   'https://images.unsplash.com/photo-1459865264687-595d652de67e?auto=format&fit=crop&w=1200&h=600&q=70'),
  ('平湖体育公园',      '张教练',  '周六 15:00',   5, 10, '初级', 3000, 120, 'open',   0.30, 0.65, now() + interval '3 days',
   'https://images.unsplash.com/photo-1579952363873-27f3bade9f55?auto=format&fit=crop&w=1200&h=600&q=70'),
  ('坂田足球场',        '阿泽',    '周日 20:00',   0, 10, '中级', 4500, 120, 'full',   0.70, 0.30, now() + interval '4 days',
   'https://images.unsplash.com/photo-1574629810360-7efbbe195018?auto=format&fit=crop&w=1200&h=600&q=70'),
  ('华南城五人制',      '林帅',    '后天 21:00',   2,  5, '中级', 6000,  60, 'open',   0.50, 0.20, now() + interval '2 days',
   'https://images.unsplash.com/photo-1551958219-acbc608c6377?auto=format&fit=crop&w=1200&h=600&q=70'),
  ('大鹏海滨球场',      '小赵',    '下周六 09:00', 4, 10, '初级', 3500, 120, 'open',   0.82, 0.55, now() + interval '6 days',
   'https://images.unsplash.com/photo-1522778119026-d647f0596c20?auto=format&fit=crop&w=1200&h=600&q=70');

-- 把归一化 (0-1) 坐标映射到真实深圳经纬度（lat ≈ 22.5, lng ≈ 114.0）。
-- 条件 lat <= 1 and lng <= 1 保证只动种子数据，不会误伤真实 pickup。
update public.pickups
   set lat = 22.5 + (lat * 0.2),
       lng = 113.9 + (lng * 0.3)
 where lat is not null
   and lng is not null
   and lat <= 1
   and lng <= 1;

-- ═══════════════════════════════════════════════════════════════
-- 2. Lineup — 首场 pickup 的 4-3-3 阵型（8 填 / 3 空）
--    空位不存行，客户端按 canonical layout 渲染虚线占位
-- ═══════════════════════════════════════════════════════════════

with target as (
  select id from pickups where venue = '龙岗体育中心 3号场' limit 1
)
delete from pickup_slots
  where pickup_id = (select id from target)
    and user_id is null
    and display_name is not null;

insert into pickup_slots (pickup_id, user_id, display_name, position, x, y)
select t.id, null, n.display_name, n.position, n.x, n.y
from (select id from pickups where venue = '龙岗体育中心 3号场' limit 1) t
cross join (values
  ('老王',   'GK', 50, 92),
  ('Kevin',  'LB', 18, 72),
  ('阿泽',   'CB', 38, 72),
  ('江北',   'RB', 82, 72),
  ('林帅',   'CM', 30, 48),
  ('小赵',   'CM', 70, 48),
  ('徐铮',   'LW', 20, 22),
  ('陈子睿', 'RW', 80, 22)
) as n(display_name, position, x, y);

-- ═══════════════════════════════════════════════════════════════
-- 3. Event + 16 队 + 完整 knockout16 Bracket（15 场）
--    删 event 级联删 teams / matches / goals / ratings
--    (teams.event_id, matches.event_id, goals.match_id, ratings.match_id
--     都是 ON DELETE CASCADE)
-- ═══════════════════════════════════════════════════════════════

delete from events where id = '11111111-1111-1111-1111-111111111111';

insert into events (id, name, sub, city, status, template, teams_max, prize_cents, starts_at, cover_url)
values (
  '11111111-1111-1111-1111-111111111111',
  '2026 龙岗村超',
  '第三届社区联赛',
  '深圳 · 龙岗区',
  'ongoing',
  'knockout16',
  16,
  5000000,
  now() - interval '6 days',
  'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?auto=format&fit=crop&w=1200&h=600&q=70'
);

-- 16 支参赛队（approved 全为 true，captain_id 暂不绑定，logo_url 走 6 张池循环）
insert into teams (event_id, name, approved, logo_url) values
  ('11111111-1111-1111-1111-111111111111', '龙岗狼队',     true, 'https://images.unsplash.com/photo-1521412644187-c49fa049e84d?auto=format&fit=crop&w=200&h=200&q=70'),
  ('11111111-1111-1111-1111-111111111111', 'FC 黑马',      true, 'https://images.unsplash.com/photo-1579952363873-27f3bade9f55?auto=format&fit=crop&w=200&h=200&q=70'),
  ('11111111-1111-1111-1111-111111111111', '布吉联队',     true, 'https://images.unsplash.com/photo-1431324155629-1a6deb1dec8d?auto=format&fit=crop&w=200&h=200&q=70'),
  ('11111111-1111-1111-1111-111111111111', '大运雄鹰',     true, 'https://images.unsplash.com/photo-1614632537190-23e4b2e69c88?auto=format&fit=crop&w=200&h=200&q=70'),
  ('11111111-1111-1111-1111-111111111111', '坂田红军',     true, 'https://images.unsplash.com/photo-1493924731456-15fbd6ba2ad5?auto=format&fit=crop&w=200&h=200&q=70'),
  ('11111111-1111-1111-1111-111111111111', '华南城FC',     true, 'https://images.unsplash.com/photo-1606925797300-0b35e9d1794e?auto=format&fit=crop&w=200&h=200&q=70'),
  ('11111111-1111-1111-1111-111111111111', '平湖流星',     true, 'https://images.unsplash.com/photo-1521412644187-c49fa049e84d?auto=format&fit=crop&w=200&h=200&q=70'),
  ('11111111-1111-1111-1111-111111111111', '大鹏海军',     true, 'https://images.unsplash.com/photo-1579952363873-27f3bade9f55?auto=format&fit=crop&w=200&h=200&q=70'),
  ('11111111-1111-1111-1111-111111111111', '横岗野牛',     true, 'https://images.unsplash.com/photo-1431324155629-1a6deb1dec8d?auto=format&fit=crop&w=200&h=200&q=70'),
  ('11111111-1111-1111-1111-111111111111', '园山猛虎',     true, 'https://images.unsplash.com/photo-1614632537190-23e4b2e69c88?auto=format&fit=crop&w=200&h=200&q=70'),
  ('11111111-1111-1111-1111-111111111111', '宝龙雷霆',     true, 'https://images.unsplash.com/photo-1493924731456-15fbd6ba2ad5?auto=format&fit=crop&w=200&h=200&q=70'),
  ('11111111-1111-1111-1111-111111111111', '同乐雄狮',     true, 'https://images.unsplash.com/photo-1606925797300-0b35e9d1794e?auto=format&fit=crop&w=200&h=200&q=70'),
  ('11111111-1111-1111-1111-111111111111', '爱联骑士',     true, 'https://images.unsplash.com/photo-1521412644187-c49fa049e84d?auto=format&fit=crop&w=200&h=200&q=70'),
  ('11111111-1111-1111-1111-111111111111', '盐田航海',     true, 'https://images.unsplash.com/photo-1579952363873-27f3bade9f55?auto=format&fit=crop&w=200&h=200&q=70'),
  ('11111111-1111-1111-1111-111111111111', '南联铁骑',     true, 'https://images.unsplash.com/photo-1431324155629-1a6deb1dec8d?auto=format&fit=crop&w=200&h=200&q=70'),
  ('11111111-1111-1111-1111-111111111111', '低碳城飞翼',   true, 'https://images.unsplash.com/photo-1614632537190-23e4b2e69c88?auto=format&fit=crop&w=200&h=200&q=70');

-- 首场 QF 用稳定 UUID（客户端 demoMatchId 引用）。其余 matches 默认 gen_random_uuid。
insert into matches (id, event_id, round, team_a_label, team_b_label,
                     score_a, score_b, pk_score, played_at, done) values
  ('22222222-2222-2222-2222-222222222222',
   '11111111-1111-1111-1111-111111111111', 'qf',    '龙岗狼队', 'FC 黑马',   3, 1, null,  now() - interval '3 days', true);

insert into matches (event_id, round, team_a_label, team_b_label,
                     score_a, score_b, pk_score, played_at, done) values
  -- R16 — 全部已完赛
  ('11111111-1111-1111-1111-111111111111', 'r16',   '龙岗狼队', '低碳城飞翼', 4, 0, null,  now() - interval '6 days', true),
  ('11111111-1111-1111-1111-111111111111', 'r16',   'FC 黑马',  '南联铁骑',   2, 1, null,  now() - interval '6 days', true),
  ('11111111-1111-1111-1111-111111111111', 'r16',   '布吉联队', '盐田航海',   3, 1, null,  now() - interval '6 days', true),
  ('11111111-1111-1111-1111-111111111111', 'r16',   '大运雄鹰', '爱联骑士',   2, 2, '5-3', now() - interval '5 days', true),
  ('11111111-1111-1111-1111-111111111111', 'r16',   '坂田红军', '同乐雄狮',   1, 0, null,  now() - interval '5 days', true),
  ('11111111-1111-1111-1111-111111111111', 'r16',   '华南城FC', '宝龙雷霆',   3, 2, null,  now() - interval '5 days', true),
  ('11111111-1111-1111-1111-111111111111', 'r16',   '平湖流星', '园山猛虎',   5, 1, null,  now() - interval '5 days', true),
  ('11111111-1111-1111-1111-111111111111', 'r16',   '大鹏海军', '横岗野牛',   2, 1, null,  now() - interval '4 days', true),
  -- 余下 3 QF — 全部已完赛
  ('11111111-1111-1111-1111-111111111111', 'qf',    '布吉联队', '大运雄鹰',   2, 1, null,  now() - interval '3 days', true),
  ('11111111-1111-1111-1111-111111111111', 'qf',    '坂田红军', '华南城FC',   0, 0, '5-4', now() - interval '2 days', true),
  ('11111111-1111-1111-1111-111111111111', 'qf',    '平湖流星', '大鹏海军',   4, 2, null,  now() - interval '2 days', true),
  -- SF — SF1 已完赛（龙岗狼队晋级决赛），SF2 待打
  ('11111111-1111-1111-1111-111111111111', 'sf',    '龙岗狼队', '布吉联队',   2, 0, null,  now() - interval '1 day',  true),
  ('11111111-1111-1111-1111-111111111111', 'sf',    '坂田红军', '平湖流星',   null, null, null, now() + interval '2 days', false),
  -- Final — 龙岗狼队 已锁定一席，另一席 TBD
  ('11111111-1111-1111-1111-111111111111', 'final', '龙岗狼队', 'TBD',        null, null, null, now() + interval '5 days', false);

-- 把 matches 的 team_a_id / team_b_id 按 label 回填到 teams FK
-- label='TBD' 的行无匹配 team，team_b_id 保持 null
update matches m
   set team_a_id = ta.id,
       team_b_id = tb.id
  from teams ta, teams tb
 where m.event_id = '11111111-1111-1111-1111-111111111111'
   and ta.event_id = m.event_id and ta.name = m.team_a_label
   and tb.event_id = m.event_id and tb.name = m.team_b_label;

-- ═══════════════════════════════════════════════════════════════
-- 4. Goals — 已完赛场次的进球明细
--    scorer_id 留 null，仅 scorer_name 用于 event_scorers 视图聚合
--    (视图内 coalesce(profiles.name, scorer_name) 会落到 scorer_name)
-- ═══════════════════════════════════════════════════════════════

-- QF1（demoMatchId）: 龙岗狼队 3-1 FC 黑马
insert into goals (match_id, scorer_name, minute, is_penalty, is_own_goal) values
  ('22222222-2222-2222-2222-222222222222', '陈子睿', 15, false, false),
  ('22222222-2222-2222-2222-222222222222', '老王',   34, true,  false),
  ('22222222-2222-2222-2222-222222222222', '徐铮',   78, false, false),
  ('22222222-2222-2222-2222-222222222222', 'Kevin',  58, false, false);

-- 其余 matches 按 (round, team_a_label) 定位 match_id 后插入进球
-- 每行元组：(round, team_a_label, scorer_name, minute, is_penalty, is_own_goal)
-- 其中 scorer 属于哪支队不需要在 goals 表里记，客户端只按 scorer_name 聚合射手榜
insert into goals (match_id, scorer_name, minute, is_penalty, is_own_goal)
select m.id, g.scorer_name, g.minute, g.is_penalty, g.is_own_goal
from matches m
cross join (values
  -- R16
  ('r16', '龙岗狼队', '陈子睿',  8, false, false),
  ('r16', '龙岗狼队', '徐铮',   29, false, false),
  ('r16', '龙岗狼队', '林帅',   51, false, false),
  ('r16', '龙岗狼队', '陈子睿', 72, false, false),
  ('r16', 'FC 黑马',  'Kevin',  19, false, false),
  ('r16', 'FC 黑马',  '黑马小将', 44, false, false),
  ('r16', 'FC 黑马',  '铁骑 7 号', 66, false, false),
  ('r16', '布吉联队', '阿泽',   12, false, false),
  ('r16', '布吉联队', '阿泽',   47, false, false),
  ('r16', '布吉联队', '小赵',   85, false, false),
  ('r16', '布吉联队', '航海 9 号', 58, false, false),
  ('r16', '大运雄鹰', '张教练',  33, false, false),
  ('r16', '大运雄鹰', '雄鹰 10 号', 78, false, false),
  ('r16', '大运雄鹰', '骑士 3 号', 21, false, false),
  ('r16', '大运雄鹰', '骑士 11 号', 90, false, false),
  ('r16', '坂田红军', '江北',   68, false, false),
  ('r16', '华南城FC', '陈子睿', 25, false, false),
  ('r16', '华南城FC', '华南 8 号', 50, true,  false),
  ('r16', '华南城FC', '林帅',   81, false, false),
  ('r16', '华南城FC', '雷霆 6 号', 13, false, false),
  ('r16', '华南城FC', '雷霆 9 号', 73, false, false),
  ('r16', '平湖流星', '林帅',    6, false, false),
  ('r16', '平湖流星', '徐铮',   22, false, false),
  ('r16', '平湖流星', '小赵',   41, false, false),
  ('r16', '平湖流星', '陈子睿', 63, false, false),
  ('r16', '平湖流星', '林帅',   88, false, false),
  ('r16', '平湖流星', '猛虎 5 号', 54, false, false),
  ('r16', '大鹏海军', '老王',   36, false, false),
  ('r16', '大鹏海军', '江北',   77, false, false),
  ('r16', '大鹏海军', '野牛 4 号', 62, false, false),
  -- QF (QF1 already inserted above, skip it)
  ('qf',  '布吉联队', '阿泽',   22, false, false),
  ('qf',  '布吉联队', '小赵',   67, false, false),
  ('qf',  '布吉联队', '张教练', 45, false, false),
  ('qf',  '平湖流星', '林帅',   10, false, false),
  ('qf',  '平湖流星', '陈子睿', 38, false, false),
  ('qf',  '平湖流星', '徐铮',   72, false, false),
  ('qf',  '平湖流星', '江北',   88, false, false),
  ('qf',  '平湖流星', '阿泽',   25, false, false),
  ('qf',  '平湖流星', '老王',   55, false, false),
  -- SF1: 龙岗狼队 2-0 布吉联队
  ('sf',  '龙岗狼队', '陈子睿', 33, false, false),
  ('sf',  '龙岗狼队', '徐铮',   76, false, false)
) as g(round, team_a_label, scorer_name, minute, is_penalty, is_own_goal)
where m.event_id = '11111111-1111-1111-1111-111111111111'
  and m.round = g.round
  and m.team_a_label = g.team_a_label;

-- 按 scorer_name 回填 scorer_id 到 demo profiles（仅 Section 0 的 9 位出镜主力，
-- 匿名 NPC 如 "雷霆 6 号" 保持 scorer_id = null）。
update public.goals g
set scorer_id = p.id
from public.profiles p
where g.scorer_id is null
  and p.name = g.scorer_name
  and p.id::text like '10000000-%';

-- ═══════════════════════════════════════════════════════════════
-- 5. Ratings — 虎扑式评分（仅 QF1 + SF1 两场示范）
--    rater_id / ratee_id 都 null，用 ratee_name 做 display-only
--    unique(match_id, rater_id, ratee_id) 里 NULL 互不相等不会去重，
--    partial index ratings_demo_unique 才是去重保障（ratee_id IS NULL 时生效）
-- ═══════════════════════════════════════════════════════════════

-- QF1（demoMatchId）— 8 条评分覆盖两队主力
insert into ratings (match_id, rater_id, ratee_id, ratee_name, score, comment, highlight) values
  ('22222222-2222-2222-2222-222222222222', null, null, '陈子睿', 8.5, '梅开二度，终场发挥稳定',           '2球1助'),
  ('22222222-2222-2222-2222-222222222222', null, null, '老王',   7.8, '点球一脚致胜',                     '点球破门'),
  ('22222222-2222-2222-2222-222222222222', null, null, '徐铮',   8.2, '终场锁定胜局',                     '关键进球'),
  ('22222222-2222-2222-2222-222222222222', null, null, '林帅',   7.5, '中场组织有序',                     '3次关键传球'),
  ('22222222-2222-2222-2222-222222222222', null, null, '江北',   7.0, '防守稳定，几次关键解围',           null),
  ('22222222-2222-2222-2222-222222222222', null, null, 'Kevin',  7.2, '独中一元，对方后防重点盯防',       '1球'),
  ('22222222-2222-2222-2222-222222222222', null, null, '张教练', 6.8, '组织失误较多，但保持了团队斗志',   null),
  ('22222222-2222-2222-2222-222222222222', null, null, '小赵',   6.5, '上半场手感不佳，下半场有所回勇',   null);

-- SF1: 龙岗狼队 2-0 布吉联队 — 4 条评分
insert into ratings (match_id, rater_id, ratee_id, ratee_name, score, comment, highlight)
select m.id, null, null, r.ratee_name, r.score, r.comment, r.highlight
from matches m
cross join (values
  ('陈子睿', 8.8::numeric, '半决赛 MVP，开场闪击',          '1球1助'),
  ('徐铮',   8.3::numeric, '终场反击一剑封喉',                '1球'),
  ('老王',   7.9::numeric, '门线扑救关键',                    '3次关键扑救'),
  ('阿泽',   6.9::numeric, '独木难支，但防线几次解围到位',    null)
) as r(ratee_name, score, comment, highlight)
where m.event_id = '11111111-1111-1111-1111-111111111111'
  and m.round = 'sf' and m.team_a_label = '龙岗狼队';

-- 按 ratee_name 回填 ratee_id 到 demo profiles，完成后 event_player_ratings 视图
-- 就能按 ratee_id 聚合、客户端 join profiles 拿 avatar_url。
update public.ratings r
set ratee_id = p.id
from public.profiles p
where r.ratee_id is null
  and p.name = r.ratee_name
  and p.id::text like '10000000-%';

-- ═══════════════════════════════════════════════════════════════
-- 6. Predictions — 世界杯竞猜
--    match_id 是 text（不 FK matches），客户端用 'wc-focus'/'w1'..'w5'
--    user_id NOT NULL + FK profiles：没 profile 时 SELECT 为空，INSERT no-op
--    每个现有 profile 都投同一套预测，prediction_distribution 视图
--    会显示 (profile_count) 票 * 6 条 match
-- ═══════════════════════════════════════════════════════════════

delete from predictions where match_id in ('wc-focus', 'w1', 'w2', 'w3', 'w4', 'w5');

insert into predictions (user_id, match_id, choice, stake)
select p.id, v.match_id, v.choice, v.stake
from public.profiles p
cross join (values
  ('wc-focus', 'A',    200),
  ('w1',       'A',    100),
  ('w2',       'draw', 50),
  ('w3',       'B',    150),
  ('w4',       'A',    80),
  ('w5',       'draw', 60)
) as v(match_id, choice, stake)
on conflict (user_id, match_id) do nothing;

-- ═══════════════════════════════════════════════════════════════
-- Sanity checks
-- ═══════════════════════════════════════════════════════════════

select 'demo_avatars' as what, count(*)::text as n from public.profiles
  where id::text like '10000000-%' and avatar_url is not null
union all
select 'venue_photos', count(*)::text from pickups
  where venue in (
    '龙岗体育中心 3号场', '大运公园足球场', '平湖体育公园',
    '坂田足球场',        '华南城五人制',   '大鹏海滨球场'
  ) and venue_photo_url is not null
union all
select 'event_cover', count(*)::text from events
  where id = '11111111-1111-1111-1111-111111111111' and cover_url is not null
union all
select 'team_logos',  count(*)::text from teams
  where event_id = '11111111-1111-1111-1111-111111111111' and logo_url is not null
union all
select 'ratings_linked', count(*)::text from ratings r
  join matches m on m.id = r.match_id
  where m.event_id = '11111111-1111-1111-1111-111111111111' and r.ratee_id is not null
union all
select 'goals_linked', count(*)::text from goals g
  join matches m on m.id = g.match_id
  where m.event_id = '11111111-1111-1111-1111-111111111111' and g.scorer_id is not null
union all
select 'pickups' as what, count(*)::text as n from pickups
  where venue in (
    '龙岗体育中心 3号场', '大运公园足球场', '平湖体育公园',
    '坂田足球场',        '华南城五人制',   '大鹏海滨球场'
  )
union all
select 'lineup',   count(*)::text from pickup_slots
  where pickup_id = (select id from pickups where venue = '龙岗体育中心 3号场' limit 1)
    and display_name is not null
union all
select 'teams',    count(*)::text from teams
  where event_id = '11111111-1111-1111-1111-111111111111'
union all
select 'matches',  count(*)::text from matches
  where event_id = '11111111-1111-1111-1111-111111111111'
union all
select 'matches_done', count(*)::text from matches
  where event_id = '11111111-1111-1111-1111-111111111111' and done
union all
select 'goals',    count(*)::text from goals g
  join matches m on m.id = g.match_id
  where m.event_id = '11111111-1111-1111-1111-111111111111'
union all
select 'ratings',  count(*)::text from ratings r
  join matches m on m.id = r.match_id
  where m.event_id = '11111111-1111-1111-1111-111111111111'
union all
select 'predictions', count(*)::text from predictions
  where match_id in ('wc-focus', 'w1', 'w2', 'w3', 'w4', 'w5');
