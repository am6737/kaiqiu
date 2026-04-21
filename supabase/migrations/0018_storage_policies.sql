-- docs/storage-policies.sql — Supabase Storage RLS policies for S1 buckets.
-- 在 Dashboard → SQL Editor 粘贴执行。需要先在 Storage 新建 3 个 public bucket:
--   avatars / event-covers / pickup-photos

-- avatars: 任何人读，用户只能写到以自己 uid 为前缀的路径
drop policy if exists "avatars_public_read" on storage.objects;
create policy "avatars_public_read" on storage.objects
  for select using (bucket_id = 'avatars');

drop policy if exists "avatars_self_write" on storage.objects;
create policy "avatars_self_write" on storage.objects
  for insert with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "avatars_self_update" on storage.objects;
create policy "avatars_self_update" on storage.objects
  for update using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "avatars_self_delete" on storage.objects;
create policy "avatars_self_delete" on storage.objects
  for delete using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- event-covers: 任何人读，赛事创建者（= 路径第一段 uid）能写
drop policy if exists "event_covers_public_read" on storage.objects;
create policy "event_covers_public_read" on storage.objects
  for select using (bucket_id = 'event-covers');

drop policy if exists "event_covers_self_write" on storage.objects;
create policy "event_covers_self_write" on storage.objects
  for insert with check (
    bucket_id = 'event-covers'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "event_covers_self_update" on storage.objects;
create policy "event_covers_self_update" on storage.objects
  for update using (
    bucket_id = 'event-covers'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- pickup-photos: 同样规则
drop policy if exists "pickup_photos_public_read" on storage.objects;
create policy "pickup_photos_public_read" on storage.objects
  for select using (bucket_id = 'pickup-photos');

drop policy if exists "pickup_photos_self_write" on storage.objects;
create policy "pickup_photos_self_write" on storage.objects
  for insert with check (
    bucket_id = 'pickup-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "pickup_photos_self_update" on storage.objects;
create policy "pickup_photos_self_update" on storage.objects
  for update using (
    bucket_id = 'pickup-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
