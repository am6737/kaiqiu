-- 0013_venues.sql — 场馆 + 场馆预约

create table if not exists venues (
  id         uuid primary key default gen_random_uuid(),
  owner_id   uuid not null references auth.users(id) on delete cascade,
  owner_name text,
  name       text not null,
  sport_type text default 'football',
  description text,
  address    text not null,
  lat        double precision not null,
  lng        double precision not null,
  phone      text,
  cover_url  text,
  photos     text[] default '{}',
  field_type text default 'outdoor',
  field_count int default 1,
  price_per_hour_cents int default 0,
  facilities text[] default '{}',
  opening_hours text,
  status     text default 'active',
  rating     double precision,
  review_count int default 0,
  created_at timestamptz default now()
);

create index idx_venues_owner on venues(owner_id);
create index idx_venues_sport on venues(sport_type);
create index idx_venues_status on venues(status);
create index idx_venues_location on venues(lat, lng);

-- RLS
alter table venues enable row level security;
create policy "venues readable by all" on venues for select using (true);
create policy "venues insertable by auth" on venues for insert with check (auth.uid() = owner_id);
create policy "venues updatable by owner" on venues for update using (auth.uid() = owner_id);
create policy "venues deletable by owner" on venues for delete using (auth.uid() = owner_id);

-- Auto-populate owner_name from profiles on insert
create or replace function populate_venue_owner_name()
returns trigger as $$
begin
  select name into new.owner_name
  from profiles
  where id = new.owner_id;
  return new;
end;
$$ language plpgsql security definer;

create trigger trg_venue_owner_name
  before insert on venues
  for each row execute function populate_venue_owner_name();

-- ── Venue bookings ──

create table if not exists venue_bookings (
  id         uuid primary key default gen_random_uuid(),
  venue_id   uuid not null references venues(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  user_name  text,
  user_phone text,
  date       date not null,
  start_time text not null,
  end_time   text not null,
  total_cents int default 0,
  status     text default 'pending',
  note       text,
  created_at timestamptz default now()
);

create index idx_vb_venue on venue_bookings(venue_id);
create index idx_vb_user on venue_bookings(user_id);
create index idx_vb_date on venue_bookings(venue_id, date);

-- RLS
alter table venue_bookings enable row level security;
create policy "bookings readable by venue owner or booker"
  on venue_bookings for select
  using (
    auth.uid() = user_id
    or auth.uid() in (select owner_id from venues where id = venue_id)
  );
create policy "bookings insertable by auth" on venue_bookings for insert
  with check (auth.uid() = user_id);
create policy "bookings updatable by venue owner"
  on venue_bookings for update
  using (
    auth.uid() in (select owner_id from venues where id = venue_id)
  );

-- Auto-populate user_name from profiles on insert
create or replace function populate_booking_user_name()
returns trigger as $$
begin
  select name into new.user_name
  from profiles
  where id = new.user_id;
  return new;
end;
$$ language plpgsql security definer;

create trigger trg_booking_user_name
  before insert on venue_bookings
  for each row execute function populate_booking_user_name();
