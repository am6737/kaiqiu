-- 0005_pickup_display_fields.sql — add display-layer columns to pickups
-- so we can store the exact mock display strings (host name, time label,
-- seats needed) without needing real user accounts or slot rows yet.
--
-- Idempotent: safe to run multiple times.

alter table pickups add column if not exists host_name  text;
alter table pickups add column if not exists time_label text;   -- e.g. "今晚 19:30"
alter table pickups add column if not exists need       int;    -- mock "缺 N 人"
