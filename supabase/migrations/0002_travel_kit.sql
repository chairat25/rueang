-- ============================================================================
-- Rueang · 0002_travel_kit.sql
-- KIT: Travel — เสียบเพิ่มบน core, opt-in ต่อเรื่อง
-- กฎ: kit อ้าง core ได้ / core ห้ามอ้าง kit
-- ปิดโหมด = topics.is_travel_enabled = false เท่านั้น "ห้ามลบแถวในไฟล์นี้"
-- ============================================================================

create table trips (
  topic_id          uuid primary key references topics(id) on delete cascade,
  owner_id          uuid not null references auth.users(id) on delete cascade,
  destination_label text check (destination_label is null or char_length(destination_label) <= 200),
  start_date        date,
  end_date          date,
  currency          char(3) not null default 'THB',
  budget_total      numeric(12,2) check (budget_total is null or budget_total >= 0),
  notes             text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  constraint trip_date_order check (start_date is null or end_date is null or end_date >= start_date)
);

create trigger trips_set_updated_at before update on trips
  for each row execute function set_updated_at();

create table trip_days (
  id         uuid primary key default gen_random_uuid(),
  topic_id   uuid not null references trips(topic_id) on delete cascade,
  owner_id   uuid not null references auth.users(id) on delete cascade,
  day_index  integer not null check (day_index between 1 and 366),
  date       date,
  title      text check (title is null or char_length(title) <= 200),
  note       text,
  created_at timestamptz not null default now(),
  unique (topic_id, day_index)
);

create index trip_days_topic_idx on trip_days (topic_id, day_index);

do $$ begin
  create type stop_status as enum ('planned','confirmed','skipped','done');
exception when duplicate_object then null; end $$;

create table trip_stops (
  id               uuid primary key default gen_random_uuid(),
  topic_id         uuid not null references trips(topic_id) on delete cascade,
  owner_id         uuid not null references auth.users(id) on delete cascade,
  -- day_id = null → "กองรอจัด" (เก็บไว้แล้วแต่ยังไม่รู้จะไปวันไหน)
  day_id           uuid references trip_days(id) on delete set null,
  -- entry ต้นทาง: ลบ entry แล้ว stop ต้องยังอยู่ แค่ปุ่ม "ที่มา" หายไป
  entry_id         uuid references entries(id) on delete set null,

  name             text not null check (char_length(trim(name)) between 1 and 200),
  note             text,
  planned_start    time,
  duration_minutes integer check (duration_minutes is null or duration_minutes between 1 and 1440),
  est_cost         numeric(12,2) check (est_cost is null or est_cost >= 0),
  status           stop_status not null default 'planned',
  sort_order       double precision not null default 0,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create index trip_stops_day_idx     on trip_stops (topic_id, day_id, sort_order);
create index trip_stops_backlog_idx on trip_stops (topic_id, sort_order) where day_id is null;
create index trip_stops_entry_idx   on trip_stops (entry_id);

create trigger trip_stops_set_updated_at before update on trip_stops
  for each row execute function set_updated_at();

create table checklist_items (
  id         uuid primary key default gen_random_uuid(),
  topic_id   uuid not null references trips(topic_id) on delete cascade,
  owner_id   uuid not null references auth.users(id) on delete cascade,
  label      text not null check (char_length(trim(label)) between 1 and 200),
  category   text check (category is null or char_length(category) <= 50),
  is_done    boolean not null default false,
  sort_order double precision not null default 0,
  created_at timestamptz not null default now()
);

create index checklist_items_topic_idx on checklist_items (topic_id, sort_order);

create table budget_items (
  id         uuid primary key default gen_random_uuid(),
  topic_id   uuid not null references trips(topic_id) on delete cascade,
  owner_id   uuid not null references auth.users(id) on delete cascade,
  label      text not null check (char_length(trim(label)) between 1 and 200),
  category   text check (category is null or category in
                ('transport','stay','food','activity','shopping','other')),
  amount     numeric(12,2) not null check (amount >= 0),
  is_paid    boolean not null default false,
  created_at timestamptz not null default now()
);

create index budget_items_topic_idx on budget_items (topic_id);
