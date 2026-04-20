-- 0021_pickup_address.sql — add detailed street address for pickups
--
-- `venue` is a short venue name ("莲花山足球场"). `address` is the optional
-- full street-level address shown on the detail page and passed to external
-- map apps via URL schemes. Nullable so existing rows and seed data keep
-- working untouched.

alter table public.pickups
  add column if not exists address text;
