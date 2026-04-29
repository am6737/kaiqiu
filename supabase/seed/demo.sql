-- demo.sql — 测试账户 seed（在 0001_schema.sql 之后执行）
-- 统一密码: kaiqiu
--
-- 插入 auth.users 后 handle_new_user trigger 会自动创建 profiles。
-- 之后再 UPDATE profiles 补充 city / position 等字段。

-- ═══════════════════════════════════════════════════════════════
-- 0. 清空旧数据，确保幂等（禁用 FK 检查后逐表清理）
-- ═══════════════════════════════════════════════════════════════

SET session_replication_role = replica;

DELETE FROM public.pickups;
DELETE FROM public.pickup_slots;
DELETE FROM public.posts;
DELETE FROM public.articles;
DELETE FROM public.profiles;
DELETE FROM auth.identities;
DELETE FROM auth.sessions;
DELETE FROM auth.refresh_tokens;
DELETE FROM auth.users;

SET session_replication_role = DEFAULT;

-- ═══════════════════════════════════════════════════════════════
-- 1. auth.users — 13 个测试账户
-- ═══════════════════════════════════════════════════════════════

INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, last_sign_in_at,
  raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at,
  confirmation_token, email_change, email_change_token_new, recovery_token
) VALUES
  ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','demo-chenzirui@qiuju.local', crypt('kaiqiu',gen_salt('bf')), now(),now(), '{"provider":"email","providers":["email"]}'::jsonb, '{"name":"陈子睿"}'::jsonb,  now(),now(),'','','',''),
  ('10000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','demo-laowang@qiuju.local',   crypt('kaiqiu',gen_salt('bf')), now(),now(), '{"provider":"email","providers":["email"]}'::jsonb, '{"name":"老王"}'::jsonb,    now(),now(),'','','',''),
  ('10000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','demo-xuzheng@qiuju.local',   crypt('kaiqiu',gen_salt('bf')), now(),now(), '{"provider":"email","providers":["email"]}'::jsonb, '{"name":"徐铮"}'::jsonb,    now(),now(),'','','',''),
  ('10000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000000','authenticated','authenticated','demo-linshuai@qiuju.local',  crypt('kaiqiu',gen_salt('bf')), now(),now(), '{"provider":"email","providers":["email"]}'::jsonb, '{"name":"林帅"}'::jsonb,    now(),now(),'','','',''),
  ('10000000-0000-0000-0000-000000000005','00000000-0000-0000-0000-000000000000','authenticated','authenticated','demo-jiangbei@qiuju.local',  crypt('kaiqiu',gen_salt('bf')), now(),now(), '{"provider":"email","providers":["email"]}'::jsonb, '{"name":"江北"}'::jsonb,    now(),now(),'','','',''),
  ('10000000-0000-0000-0000-000000000006','00000000-0000-0000-0000-000000000000','authenticated','authenticated','demo-kevin@qiuju.local',     crypt('kaiqiu',gen_salt('bf')), now(),now(), '{"provider":"email","providers":["email"]}'::jsonb, '{"name":"Kevin"}'::jsonb,   now(),now(),'','','',''),
  ('10000000-0000-0000-0000-000000000007','00000000-0000-0000-0000-000000000000','authenticated','authenticated','demo-coach@qiuju.local',     crypt('kaiqiu',gen_salt('bf')), now(),now(), '{"provider":"email","providers":["email"]}'::jsonb, '{"name":"张教练"}'::jsonb,  now(),now(),'','','',''),
  ('10000000-0000-0000-0000-000000000008','00000000-0000-0000-0000-000000000000','authenticated','authenticated','demo-xiaozhao@qiuju.local',  crypt('kaiqiu',gen_salt('bf')), now(),now(), '{"provider":"email","providers":["email"]}'::jsonb, '{"name":"小赵"}'::jsonb,    now(),now(),'','','',''),
  ('10000000-0000-0000-0000-000000000009','00000000-0000-0000-0000-000000000000','authenticated','authenticated','demo-aze@qiuju.local',       crypt('kaiqiu',gen_salt('bf')), now(),now(), '{"provider":"email","providers":["email"]}'::jsonb, '{"name":"阿泽"}'::jsonb,    now(),now(),'','','',''),
  ('10000000-0000-0000-0000-00000000000a','00000000-0000-0000-0000-000000000000','authenticated','authenticated','demo-lurenjia@qiuju.local',  crypt('kaiqiu',gen_salt('bf')), now(),now(), '{"provider":"email","providers":["email"]}'::jsonb, '{"name":"路人甲"}'::jsonb,  now(),now(),'','','',''),
  ('10000000-0000-0000-0000-00000000000b','00000000-0000-0000-0000-000000000000','authenticated','authenticated','demo-lurenyi@qiuju.local',   crypt('kaiqiu',gen_salt('bf')), now(),now(), '{"provider":"email","providers":["email"]}'::jsonb, '{"name":"路人乙"}'::jsonb,  now(),now(),'','','',''),
  ('10000000-0000-0000-0000-00000000000c','00000000-0000-0000-0000-000000000000','authenticated','authenticated','demo-lurenbing@qiuju.local', crypt('kaiqiu',gen_salt('bf')), now(),now(), '{"provider":"email","providers":["email"]}'::jsonb, '{"name":"路人丙"}'::jsonb,  now(),now(),'','','',''),
  ('10000000-0000-0000-0000-00000000000d','00000000-0000-0000-0000-000000000000','authenticated','authenticated','demo-lurending@qiuju.local', crypt('kaiqiu',gen_salt('bf')), now(),now(), '{"provider":"email","providers":["email"]}'::jsonb, '{"name":"路人丁"}'::jsonb,  now(),now(),'','','','');

-- ═══════════════════════════════════════════════════════════════
-- 2. auth.identities — 邮箱登录所需（每人一条 email provider 记录）
-- ═══════════════════════════════════════════════════════════════

INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
VALUES
  (gen_random_uuid(), '10000000-0000-0000-0000-000000000001', jsonb_build_object('sub','10000000-0000-0000-0000-000000000001','email','demo-chenzirui@qiuju.local'), 'email', '10000000-0000-0000-0000-000000000001', now(), now(), now()),
  (gen_random_uuid(), '10000000-0000-0000-0000-000000000002', jsonb_build_object('sub','10000000-0000-0000-0000-000000000002','email','demo-laowang@qiuju.local'),   'email', '10000000-0000-0000-0000-000000000002', now(), now(), now()),
  (gen_random_uuid(), '10000000-0000-0000-0000-000000000003', jsonb_build_object('sub','10000000-0000-0000-0000-000000000003','email','demo-xuzheng@qiuju.local'),   'email', '10000000-0000-0000-0000-000000000003', now(), now(), now()),
  (gen_random_uuid(), '10000000-0000-0000-0000-000000000004', jsonb_build_object('sub','10000000-0000-0000-0000-000000000004','email','demo-linshuai@qiuju.local'),  'email', '10000000-0000-0000-0000-000000000004', now(), now(), now()),
  (gen_random_uuid(), '10000000-0000-0000-0000-000000000005', jsonb_build_object('sub','10000000-0000-0000-0000-000000000005','email','demo-jiangbei@qiuju.local'),  'email', '10000000-0000-0000-0000-000000000005', now(), now(), now()),
  (gen_random_uuid(), '10000000-0000-0000-0000-000000000006', jsonb_build_object('sub','10000000-0000-0000-0000-000000000006','email','demo-kevin@qiuju.local'),     'email', '10000000-0000-0000-0000-000000000006', now(), now(), now()),
  (gen_random_uuid(), '10000000-0000-0000-0000-000000000007', jsonb_build_object('sub','10000000-0000-0000-0000-000000000007','email','demo-coach@qiuju.local'),     'email', '10000000-0000-0000-0000-000000000007', now(), now(), now()),
  (gen_random_uuid(), '10000000-0000-0000-0000-000000000008', jsonb_build_object('sub','10000000-0000-0000-0000-000000000008','email','demo-xiaozhao@qiuju.local'),  'email', '10000000-0000-0000-0000-000000000008', now(), now(), now()),
  (gen_random_uuid(), '10000000-0000-0000-0000-000000000009', jsonb_build_object('sub','10000000-0000-0000-0000-000000000009','email','demo-aze@qiuju.local'),       'email', '10000000-0000-0000-0000-000000000009', now(), now(), now()),
  (gen_random_uuid(), '10000000-0000-0000-0000-00000000000a', jsonb_build_object('sub','10000000-0000-0000-0000-00000000000a','email','demo-lurenjia@qiuju.local'),  'email', '10000000-0000-0000-0000-00000000000a', now(), now(), now()),
  (gen_random_uuid(), '10000000-0000-0000-0000-00000000000b', jsonb_build_object('sub','10000000-0000-0000-0000-00000000000b','email','demo-lurenyi@qiuju.local'),   'email', '10000000-0000-0000-0000-00000000000b', now(), now(), now()),
  (gen_random_uuid(), '10000000-0000-0000-0000-00000000000c', jsonb_build_object('sub','10000000-0000-0000-0000-00000000000c','email','demo-lurenbing@qiuju.local'), 'email', '10000000-0000-0000-0000-00000000000c', now(), now(), now()),
  (gen_random_uuid(), '10000000-0000-0000-0000-00000000000d', jsonb_build_object('sub','10000000-0000-0000-0000-00000000000d','email','demo-lurending@qiuju.local'), 'email', '10000000-0000-0000-0000-00000000000d', now(), now(), now());

-- ═══════════════════════════════════════════════════════════════
-- 3. profiles 补充信息（trigger 只写了 id + name，这里补 city/position 等）
-- ═══════════════════════════════════════════════════════════════

UPDATE public.profiles SET city = '南宁市', position = 'ST'  WHERE id = '10000000-0000-0000-0000-000000000001';
UPDATE public.profiles SET city = '南宁市', position = 'GK'  WHERE id = '10000000-0000-0000-0000-000000000002';
UPDATE public.profiles SET city = '南宁市', position = 'CB'  WHERE id = '10000000-0000-0000-0000-000000000003';
UPDATE public.profiles SET city = '南宁市', position = 'CM'  WHERE id = '10000000-0000-0000-0000-000000000004';
UPDATE public.profiles SET city = '南宁市', position = 'LW'  WHERE id = '10000000-0000-0000-0000-000000000005';
UPDATE public.profiles SET city = '深圳市', position = 'RW'  WHERE id = '10000000-0000-0000-0000-000000000006';
UPDATE public.profiles SET city = '深圳市', position = 'CM'  WHERE id = '10000000-0000-0000-0000-000000000007';
UPDATE public.profiles SET city = '深圳市', position = 'LB'  WHERE id = '10000000-0000-0000-0000-000000000008';
UPDATE public.profiles SET city = '北京市', position = 'RB'  WHERE id = '10000000-0000-0000-0000-000000000009';
UPDATE public.profiles SET city = '北京市'                    WHERE id = '10000000-0000-0000-0000-00000000000a';
UPDATE public.profiles SET city = '北京市'                    WHERE id = '10000000-0000-0000-0000-00000000000b';
UPDATE public.profiles SET city = '广州市'                    WHERE id = '10000000-0000-0000-0000-00000000000c';
UPDATE public.profiles SET city = '广州市'                    WHERE id = '10000000-0000-0000-0000-00000000000d';

-- ═══════════════════════════════════════════════════════════════
-- 4. demo 约球（南宁 3 条、深圳 2 条、北京 1 条）
-- ═══════════════════════════════════════════════════════════════

INSERT INTO public.pickups (id, host_id, host_name, title, venue, address, lat, lng, start_at, duration_min, total, need, level, fee_cents, formation, field_type, status, city, time_label)
VALUES
  (gen_random_uuid(), '10000000-0000-0000-0000-000000000001', '陈子睿', '周三晚场', '五象总部基地', '总部基地地铁站K口步行440米', 22.7690, 108.3920, now() + interval '1 day' + time '19:30', 90, 11, 8, 'intermediate', 5000, '4-3-3', '11人制', 'open', '南宁市', '明晚 19:30'),
  (gen_random_uuid(), '10000000-0000-0000-0000-000000000002', '老王',   '免费野球', '李宁体育公园', '青秀区凤岭南路16号', 22.8100, 108.4050, now() + interval '2 days' + time '18:00', 120, 10, 6, 'beginner', 0, '4-3-3', '11人制', 'open', '南宁市', '后天 18:00'),
  (gen_random_uuid(), '10000000-0000-0000-0000-000000000004', '林帅',   '周末约一场', '广西体育中心', '良庆区五象大道东段', 22.7850, 108.3700, now() + interval '3 days' + time '09:00', 90, 14, 10, 'intermediate', 3000, '4-4-2', '11人制', 'open', '南宁市', '周末 09:00'),
  (gen_random_uuid(), '10000000-0000-0000-0000-000000000006', 'Kevin',  '莲花山约球', '莲花山足球场', '福田区莲花路', 22.5560, 114.0580, now() + interval '1 day' + time '20:00', 90, 11, 7, 'advanced', 8000, '4-3-3', '11人制', 'open', '深圳市', '明晚 20:00'),
  (gen_random_uuid(), '10000000-0000-0000-0000-000000000007', '张教练', '教练带队训练', '深圳湾体育中心', '南山区滨海大道', 22.5200, 113.9450, now() + interval '2 days' + time '16:00', 120, 16, 12, 'beginner', 0, '3-5-2', '11人制', 'open', '深圳市', '后天 16:00'),
  (gen_random_uuid(), '10000000-0000-0000-0000-000000000009', '阿泽',   '工体夜场', '工人体育场', '朝阳区工人体育场北路', 39.9310, 116.4430, now() + interval '1 day' + time '21:00', 90, 10, 5, 'intermediate', 6000, '4-3-3', '8人制', 'open', '北京市', '明晚 21:00');

-- ═══════════════════════════════════════════════════════════════
-- 4b. demo 场馆（南宁 3 条、深圳 2 条、北京 1 条）
-- ═══════════════════════════════════════════════════════════════

INSERT INTO public.venues (owner_id, name, venue_type, sport_type, address, city, lat, lng, field_type, field_count, price_per_hour_cents, facilities, opening_hours, status, description)
VALUES
  ('10000000-0000-0000-0000-000000000001', '五象总部基地足球场', 'private', 'football', '总部基地地铁站K口步行440米', '南宁市', 22.7690, 108.3920, 'outdoor', 2, 15000, ARRAY['灯光','停车场','更衣室','饮水'], '08:00-22:00', 'active', '五象新区最大的足球场，双标准场，人工草皮质量好'),
  ('10000000-0000-0000-0000-000000000002', '李宁体育公园', 'public', 'football', '青秀区凤岭南路16号', '南宁市', 22.8100, 108.4050, 'outdoor', 3, 0, ARRAY['灯光','停车场','洗手间','观众席'], NULL, 'active', '公共免费球场，场地开阔，先到先得'),
  ('10000000-0000-0000-0000-000000000004', '广西体育中心足球场', 'private', 'football', '良庆区五象大道东段', '南宁市', 22.7850, 108.3700, 'outdoor', 4, 20000, ARRAY['灯光','停车场','更衣室','淋浴','饮水','观众席'], '06:00-23:00', 'active', '专业级别场地，承办过多次市级赛事'),
  ('10000000-0000-0000-0000-000000000006', '莲花山足球场', 'private', 'football', '福田区莲花路', '深圳市', 22.5560, 114.0580, 'outdoor', 2, 18000, ARRAY['灯光','停车场','更衣室','饮水'], '07:00-22:30', 'active', '莲花山脚下，交通便利，约球热门场地'),
  ('10000000-0000-0000-0000-000000000007', '深圳湾体育中心', 'public', 'football', '南山区滨海大道', '深圳市', 22.5200, 113.9450, 'outdoor', 5, 0, ARRAY['灯光','停车场','洗手间','淋浴','观众席','WiFi'], NULL, 'active', '市级公共体育中心，设施齐全'),
  ('10000000-0000-0000-0000-000000000009', '工人体育场训练场', 'private', 'football', '朝阳区工人体育场北路', '北京市', 39.9310, 116.4430, 'outdoor', 2, 25000, ARRAY['灯光','停车场','更衣室','淋浴','储物柜'], '08:00-22:00', 'active', '工体旁边的训练场，夜场灯光好');

-- ═══════════════════════════════════════════════════════════════
-- 4c. demo 赛事（南宁 2 条、深圳 1 条）
-- ═══════════════════════════════════════════════════════════════

INSERT INTO public.events (creator_id, name, city, address, lat, lng, template, team_size, teams_max, fee_cents, starts_at, ends_at, status)
VALUES
  ('10000000-0000-0000-0000-000000000001', '2026南宁业余联赛', '南宁市', '广西体育中心', 22.7850, 108.3700, 'league', 11, 16, 20000, now() + interval '7 days', now() + interval '60 days', 'registering'),
  ('10000000-0000-0000-0000-000000000004', '五象杯邀请赛', '南宁市', '五象总部基地足球场', 22.7690, 108.3920, 'knockout16', 11, 16, 10000, now() + interval '14 days', now() + interval '16 days', 'registering'),
  ('10000000-0000-0000-0000-000000000006', '深圳龙岗杯2026', '深圳市', '深圳湾体育中心', 22.5200, 113.9450, 'group8', 11, 8, 30000, now() + interval '10 days', now() + interval '30 days', 'registering');

-- ═══════════════════════════════════════════════════════════════
-- 5. demo 动态（各城市各几条）
-- ═══════════════════════════════════════════════════════════════

INSERT INTO public.posts (author_id, body, tags, city, venue)
VALUES
  ('10000000-0000-0000-0000-000000000001', '今天在五象踢了一场，4-2大胜！进了两个，状态不错💪', ARRAY['约球','进球'], '南宁市', '五象总部基地'),
  ('10000000-0000-0000-0000-000000000002', '找了个新场地，草皮质量不错，推荐给大家', ARRAY['场地推荐'], '南宁市', '李宁体育公园'),
  ('10000000-0000-0000-0000-000000000004', '膝盖恢复得差不多了，下周可以上场了', ARRAY['伤病恢复'], '南宁市', NULL),
  ('10000000-0000-0000-0000-000000000006', '深圳的天气太适合踢球了，全年无休', ARRAY['足球'], '深圳市', NULL),
  ('10000000-0000-0000-0000-000000000007', '今天带的新手班进步很大，有两个已经能打比赛了', ARRAY['训练','新手'], '深圳市', '深圳湾体育中心'),
  ('10000000-0000-0000-0000-000000000009', '北京的球友们，周末工体约吗？', ARRAY['约球','工体'], '北京市', '工人体育场'),
  ('10000000-0000-0000-0000-00000000000a', '第一次踢11人制，累到不行但很爽', ARRAY['新手','11人制'], '北京市', NULL),
  ('10000000-0000-0000-0000-00000000000c', '广州这边有没有野球群可以加？', ARRAY['约球','广州'], '广州市', NULL);

-- ═══════════════════════════════════════════════════════════════
-- 6. demo 文章（各城市几条）
-- ═══════════════════════════════════════════════════════════════

INSERT INTO public.articles (author_id, title, summary, body, category, city)
VALUES
  ('10000000-0000-0000-0000-000000000003', '南宁业余联赛本周战报', '第5轮比赛结果汇总', '本周南宁业余联赛第5轮已全部结束，A组积分榜变化较大...', 'news', '南宁市'),
  ('10000000-0000-0000-0000-000000000001', '五象片区球场全攻略', '五象新区主要足球场地盘点', '五象新区近几年新建了不少球场，本文为大家盘点一下...', 'review', '南宁市'),
  ('10000000-0000-0000-0000-000000000007', '新手如何快速融入野球局', '给刚开始踢球的朋友一些建议', '很多朋友想踢球但不知道怎么融入，这里分享几个心得...', 'opinion', '深圳市'),
  ('10000000-0000-0000-0000-000000000006', '深圳龙岗杯赛事回顾', '2026龙岗杯八强赛精彩集锦', '今年的龙岗杯竞争格外激烈，八强赛中出现了多场逆转...', 'analysis', '深圳市'),
  ('10000000-0000-0000-0000-000000000009', '北京冬季室内球场推荐', '冬天也要踢球！室内场地指南', '北京冬天室外踢球太冷，推荐几个不错的室内场地...', 'review', '北京市');
