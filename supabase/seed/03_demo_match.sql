-- 03_demo_match.sql — one event + one match for the rating flow to target.
--
-- Uses stable UUIDs so the client can reference the match id as a constant
-- (see lib/providers.dart → demoMatchId).

-- Clean slate (safe to re-run)
delete from ratings  where match_id = '22222222-2222-2222-2222-222222222222';
delete from matches  where id       = '22222222-2222-2222-2222-222222222222';
delete from events   where id       = '11111111-1111-1111-1111-111111111111';

insert into events (id, name, sub, city, status, template, teams_max, prize_cents)
values (
  '11111111-1111-1111-1111-111111111111',
  '2026 龙岗村超',
  '第三届社区联赛',
  '深圳 · 龙岗区',
  'ongoing',
  'knockout16',
  16,
  5000000
);

insert into matches (id, event_id, round, team_a_label, team_b_label, score_a, score_b, played_at, done)
values (
  '22222222-2222-2222-2222-222222222222',
  '11111111-1111-1111-1111-111111111111',
  'qf',
  '龙岗狼队',
  'FC 黑马',
  3,
  1,
  now() - interval '2 days',
  true
);

-- Sanity
select id, round, team_a_label, team_b_label from matches
  where id = '22222222-2222-2222-2222-222222222222';
