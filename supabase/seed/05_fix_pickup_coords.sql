-- 0020_fix_pickup_coords.sql — 把种子数据的归一化 (0-1) lat/lng 转成
-- 真实深圳经纬度窗口，让 S2 地图上的 pin 落在实际街区上。
--
-- 触发条件：lat 和 lng 都小于 1（只在种子数据中出现）。真实 pickup 不会
-- 落进这个分支（深圳 lat ≈ 22.5，lng ≈ 114.0）。

update public.pickups
   set lat = 22.5 + (lat * 0.2),
       lng = 113.9 + (lng * 0.3)
 where lat is not null
   and lng is not null
   and lat <= 1
   and lng <= 1;
