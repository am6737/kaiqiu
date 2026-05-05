-- 0002_pause_match.sql — Add paused column for pause/resume in live matches
alter table public.matches add column if not exists paused boolean default false;
