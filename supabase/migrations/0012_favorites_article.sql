-- 0012_favorites_article.sql — extend favorites to support article entity type

alter table public.favorites drop constraint if exists favorites_entity_type_check;
alter table public.favorites add constraint favorites_entity_type_check
  check (entity_type in ('pickup', 'event', 'user', 'article'));
