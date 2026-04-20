-- 0017_pickup_venue_photo.sql — 场地照片列，给 S1 图片上传用

alter table public.pickups
  add column if not exists venue_photo_url text;
