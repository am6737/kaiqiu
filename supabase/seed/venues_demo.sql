-- venues_demo.sql — 场馆 demo 数据
-- Prereqs: migrations/0013_venues.sql 已应用
-- 使用 demo 用户 10000000-0000-0000-0000-000000000001 作为场馆负责人

delete from venue_bookings where venue_id in (
  'aaaaaaaa-aaaa-aaaa-aaaa-000000000001',
  'aaaaaaaa-aaaa-aaaa-aaaa-000000000002',
  'aaaaaaaa-aaaa-aaaa-aaaa-000000000003',
  'aaaaaaaa-aaaa-aaaa-aaaa-000000000004',
  'aaaaaaaa-aaaa-aaaa-aaaa-000000000005'
);

delete from venues where id in (
  'aaaaaaaa-aaaa-aaaa-aaaa-000000000001',
  'aaaaaaaa-aaaa-aaaa-aaaa-000000000002',
  'aaaaaaaa-aaaa-aaaa-aaaa-000000000003',
  'aaaaaaaa-aaaa-aaaa-aaaa-000000000004',
  'aaaaaaaa-aaaa-aaaa-aaaa-000000000005'
);

insert into venues (id, owner_id, owner_name, name, sport_type, description, address, lat, lng, phone, field_type, field_count, price_per_hour_cents, facilities, opening_hours, status, rating, review_count) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000001',
   '10000000-0000-0000-0000-000000000001', '赵铁柱',
   '阳光足球公园', 'football',
   '南宁市最大的业余足球场地，配备人工草皮和专业灯光。周末经常举办业余联赛，氛围很好。',
   '广西南宁市青秀区民族大道168号', 22.8170, 108.3665,
   '0771-5551234', 'outdoor', 3, 15000,
   '{"停车场","灯光","更衣室","饮水","洗手间"}',
   '08:00-22:00', 'active', 4.5, 128),

  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000002',
   '10000000-0000-0000-0000-000000000001', '赵铁柱',
   '翡翠室内球馆', 'football',
   '全天候室内五人制足球场，空调恒温，不受天气影响。适合下雨天约球。',
   '广西南宁市西乡塘区大学东路98号', 22.8350, 108.2880,
   '0771-5559876', 'indoor', 2, 20000,
   '{"空调","灯光","更衣室","淋浴","停车场","WiFi","储物柜"}',
   '09:00-23:00', 'active', 4.2, 56),

  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000003',
   '10000000-0000-0000-0000-000000000002', '王大锤',
   '江南体育中心足球场', 'football',
   '市政体育中心内的标准11人制足球场，天然草皮，可承办正式比赛。',
   '广西南宁市江南区壮锦大道16号', 22.7900, 108.3200,
   '0771-4882000', 'outdoor', 2, 30000,
   '{"观众席","停车场","灯光","更衣室","淋浴","洗手间"}',
   '06:00-22:00', 'active', 4.8, 210),

  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000004',
   '10000000-0000-0000-0000-000000000003', '李小龙',
   '南湖野球场', 'football',
   '南湖公园内的免费草地球场，适合周末休闲踢球。无围栏，需自带球门。',
   '广西南宁市青秀区南湖路1号（南湖公园内）', 22.8100, 108.3700,
   null, 'outdoor', 1, 0,
   '{"饮水","洗手间"}',
   '全天开放', 'active', 3.8, 42),

  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000005',
   '10000000-0000-0000-0000-000000000002', '王大锤',
   '万达篮球公园', 'basketball',
   '万达广场旁边的室外篮球场，4个标准全场，周末人多建议提前预约。',
   '广西南宁市青秀区东葛路118号', 22.8200, 108.3800,
   '13800138000', 'outdoor', 4, 5000,
   '{"灯光","饮水","停车场"}',
   '07:00-22:00', 'active', 4.0, 88);

-- 一些预约数据
insert into venue_bookings (venue_id, user_id, user_name, date, start_time, end_time, total_cents, status, note) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000001',
   '10000000-0000-0000-0000-000000000002', '王大锤',
   current_date + interval '1 day', '19:00', '21:00', 30000, 'confirmed', '11人约球，需要一号场地'),

  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000001',
   '10000000-0000-0000-0000-000000000003', '李小龙',
   current_date + interval '2 days', '14:00', '16:00', 30000, 'pending', null),

  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000002',
   '10000000-0000-0000-0000-000000000004', '陈七',
   current_date + interval '1 day', '20:00', '22:00', 40000, 'confirmed', '五人制友谊赛');
