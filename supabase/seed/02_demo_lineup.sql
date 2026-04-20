-- 02_demo_lineup.sql — seed the formation for the first demo pickup.
--
-- Matches mock.lineup (4-3-3, 8 filled / 3 empty). Empty positions are
-- *not* stored — the client knows the canonical layout and renders dashed
-- placeholders for positions with no slot row.
--
-- Prereq: 0007_pickup_slot_display.sql has been applied (adds display_name).
-- Safe to re-run: deletes existing demo slots first.

-- Resolve pickup id
with target as (
  select id from pickups where venue = '龙岗体育中心 3号场' limit 1
)
delete from pickup_slots
  where pickup_id = (select id from target)
    and user_id is null
    and display_name is not null;

-- Insert 8 filled demo positions (display-only; user_id=null)
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

-- Sanity: should return 8
select count(*) as demo_slots from pickup_slots
  where pickup_id = (select id from pickups where venue = '龙岗体育中心 3号场' limit 1)
    and display_name is not null;
