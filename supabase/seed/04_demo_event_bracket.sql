-- 04_demo_event_bracket.sql — Populate bracket (qf/sf/final) for demo event.
--
-- Prereqs:
--   - migrations 0001-0009 applied
--   - seed 03_demo_match.sql executed (creates event 11111... + qf match 22222...)
--
-- Safe to re-run: drops every match for this event except the stable demo
-- match referenced by the client (lib/providers.dart → demoMatchId).

delete from matches
 where event_id = '11111111-1111-1111-1111-111111111111'
   and id <> '22222222-2222-2222-2222-222222222222';

-- QF: 1 already exists (龙岗狼队 3-1 FC 黑马, from 03_demo_match.sql).
-- Add 3 more QF games + 2 SF + 1 final.
insert into matches (event_id, round, team_a_label, team_b_label,
                     score_a, score_b, played_at, done) values
  ('11111111-1111-1111-1111-111111111111', 'qf',    '布吉联队', '大运雄鹰', 2, 1,    now() - interval '2 days', true),
  ('11111111-1111-1111-1111-111111111111', 'qf',    '坂田红军', '华南城FC', 0, 0,    now() - interval '1 day',  true),
  ('11111111-1111-1111-1111-111111111111', 'qf',    '平湖流星', '大鹏海军', 4, 2,    now() - interval '1 day',  true),
  ('11111111-1111-1111-1111-111111111111', 'sf',    '龙岗狼队', '布吉联队', 2, 0,    now() + interval '1 day',  false),
  ('11111111-1111-1111-1111-111111111111', 'sf',    '坂田红军', '平湖流星', null, null, now() + interval '2 days', false),
  ('11111111-1111-1111-1111-111111111111', 'final', 'TBD',     'TBD',       null, null, now() + interval '5 days', false);

-- Penalty-shootout demo on the 0-0 qf.
update matches set pk_score = '5-4'
 where event_id = '11111111-1111-1111-1111-111111111111'
   and round = 'qf' and score_a = 0 and score_b = 0;

-- Sanity
select round, count(*) as n from matches
 where event_id = '11111111-1111-1111-1111-111111111111'
 group by round order by round;
