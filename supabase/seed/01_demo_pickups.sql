-- 01_demo_pickups.sql — mock data exact match to lib/data/mock.dart `pickups`.
--
-- Prereqs: migrations 0001-0004 applied, plus 0005_pickup_display_fields.sql
-- so host_name / time_label / need columns exist.
--
-- Safe to re-run: deletes previous rows matching our mock venues first.

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
  duration_min, status, lat, lng, start_at
) values
  ('龙岗体育中心 3号场', '老王',    '今晚 19:30',  3, 10, '中级', 5000, 120, 'open',   0.40, 0.35, now() + interval '8 hours'),
  ('大运公园足球场',    'Kevin',   '明天 07:00',  1, 12, '高级', 4000,  90, 'almost', 0.60, 0.50, now() + interval '1 day'),
  ('平湖体育公园',      '张教练',  '周六 15:00',  5, 10, '初级', 3000, 120, 'open',   0.30, 0.65, now() + interval '3 days'),
  ('坂田足球场',        '阿泽',    '周日 20:00',  0, 10, '中级', 4500, 120, 'full',   0.70, 0.30, now() + interval '4 days'),
  ('华南城五人制',      '林帅',    '后天 21:00',  2,  5, '中级', 6000,  60, 'open',   0.50, 0.20, now() + interval '2 days'),
  ('大鹏海滨球场',      '小赵',    '下周六 09:00', 4, 10, '初级', 3500, 120, 'open',   0.82, 0.55, now() + interval '6 days');

-- Sanity: should return 6
select count(*) as mock_count from pickups
where venue in (
  '龙岗体育中心 3号场', '大运公园足球场', '平湖体育公园',
  '坂田足球场', '华南城五人制', '大鹏海滨球场'
);
