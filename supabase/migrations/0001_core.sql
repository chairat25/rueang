-- ============================================================================
-- Rueang · 0001_core.sql
-- แกนกลาง: profiles / topics / entries / link_previews / entry_links / attachments
-- ห้ามใส่อะไรที่เจาะจงเรื่อง "เที่ยว" ในไฟล์นี้ (ยกเว้นสวิตช์ is_travel_enabled)
-- ============================================================================

create extension if not exists "pgcrypto";
create extension if not exists "pg_trgm";
create extension if not exists "unaccent";

-- ── helper: updated_at ──────────────────────────────────────────────────────
create or replace function set_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

-- ── profiles ────────────────────────────────────────────────────────────────
create table profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url   text,
  locale       text not null default 'th' check (locale in ('th','en')),
  created_at   timestamptz not null default now()
);

-- สร้าง profile อัตโนมัติเมื่อมี user ใหม่
create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name, avatar_url)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', split_part(new.email, '@', 1)),
    new.raw_user_meta_data ->> 'avatar_url'
  )
  on conflict (id) do nothing;
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- ── topics (เรื่อง) ─────────────────────────────────────────────────────────
do $$ begin
  create type topic_status as enum ('active','archived');
exception when duplicate_object then null; end $$;

create table topics (
  id          uuid primary key default gen_random_uuid(),
  owner_id    uuid not null references auth.users(id) on delete cascade,

  title       text not null check (char_length(trim(title)) between 1 and 200),
  description text check (description is null or char_length(description) <= 2000),
  tags        text[] not null default '{}',
  color       text check (color is null or color ~ '^#[0-9a-fA-F]{6}$'),
  status      topic_status not null default 'active',

  -- สวิตช์ของ travel kit (ข้อมูลทริปจริงอยู่ตาราง trips ใน 0002)
  is_travel_enabled           boolean not null default false,
  travel_suggestion_dismissed boolean not null default false,

  -- public share
  is_public   boolean not null default false,
  share_slug  text unique check (share_slug is null or share_slug ~ '^[a-z0-9]{12,24}$'),

  -- counters (ดูแลโดย trigger ท้ายไฟล์)
  entry_count   integer not null default 0 check (entry_count >= 0),
  last_entry_at timestamptz,

  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz,

  constraint public_topic_needs_slug check (not is_public or share_slug is not null)
);

create index topics_owner_active_idx on topics (owner_id, last_entry_at desc nulls last)
  where deleted_at is null;
create index topics_share_slug_idx  on topics (share_slug) where is_public and deleted_at is null;
create index topics_tags_idx        on topics using gin (tags);
create index topics_title_trgm_idx  on topics using gin (title gin_trgm_ops);

create trigger topics_set_updated_at before update on topics
  for each row execute function set_updated_at();

-- ── entries ─────────────────────────────────────────────────────────────────
-- entry ไม่มี "ชนิด": body ว่างได้ + มีลิงก์/ไฟล์กี่อันก็ได้
-- ข้อบังคับ "ต้องมีอย่างน้อย 1 อย่าง" เช็คข้าม 3 ตาราง → บังคับที่ Zod ชั้น service
create table entries (
  id         uuid primary key default gen_random_uuid(),
  topic_id   uuid not null references topics(id) on delete cascade,
  owner_id   uuid not null references auth.users(id) on delete cascade,

  title      text check (title is null or char_length(title) <= 300),
  body       text check (body  is null or char_length(body)  <= 20000),

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index entries_topic_idx      on entries (topic_id, created_at desc) where deleted_at is null;
create index entries_owner_idx      on entries (owner_id) where deleted_at is null;
create index entries_body_trgm_idx  on entries using gin (body gin_trgm_ops);
create index entries_title_trgm_idx on entries using gin (title gin_trgm_ops);

create trigger entries_set_updated_at before update on entries
  for each row execute function set_updated_at();

-- ── link_previews (cache กลาง ใช้ร่วมกันทุก user, ไม่มีข้อมูลส่วนตัว) ────────
do $$ begin
  create type link_preview_status as enum ('pending','ready','failed');
exception when duplicate_object then null; end $$;

create table link_previews (
  url_hash       text primary key check (url_hash ~ '^[0-9a-f]{64}$'),  -- sha256 ของ normalized url
  url            text not null,
  provider       text,                       -- tiktok | youtube | instagram | generic
  title          text,
  description    text,
  image_url      text,
  author_name    text,
  status         link_preview_status not null default 'pending',
  error_reason   text,
  fetch_attempts integer not null default 0 check (fetch_attempts >= 0),
  fetched_at     timestamptz,
  expires_at     timestamptz,
  created_at     timestamptz not null default now()
);

create index link_previews_stale_idx on link_previews (expires_at) where status = 'ready';

-- ── entry_links ─────────────────────────────────────────────────────────────
-- FK ไป link_previews แบบ restrict → ต้อง upsert link_previews (pending) ก่อนเสมอ
create table entry_links (
  id         uuid primary key default gen_random_uuid(),
  entry_id   uuid not null references entries(id) on delete cascade,
  owner_id   uuid not null references auth.users(id) on delete cascade,
  url        text not null check (url ~ '^https?://'),
  url_hash   text not null references link_previews(url_hash) on delete restrict,
  position   integer not null default 0 check (position >= 0),
  created_at timestamptz not null default now()
);

create index entry_links_entry_idx on entry_links (entry_id, position);
create index entry_links_hash_idx  on entry_links (url_hash);

-- ── attachments ─────────────────────────────────────────────────────────────
create table attachments (
  id            uuid primary key default gen_random_uuid(),
  topic_id      uuid not null references topics(id) on delete cascade,
  entry_id      uuid references entries(id) on delete cascade,
  owner_id      uuid not null references auth.users(id) on delete cascade,

  storage_path  text not null unique,
  original_name text not null check (char_length(original_name) between 1 and 255),
  mime_type     text not null,
  size_bytes    bigint not null check (size_bytes > 0 and size_bytes <= 26214400), -- 25 MB
  checksum      text,
  width         integer check (width  is null or width  > 0),
  height        integer check (height is null or height > 0),
  created_at    timestamptz not null default now()
);

create index attachments_entry_idx on attachments (entry_id);
create index attachments_topic_idx on attachments (topic_id);

-- ── counters: entry_count / last_entry_at ───────────────────────────────────
-- นับใหม่ทั้งหมดทุกครั้ง (self-healing) — จำนวน entry ต่อเรื่องน้อย ความถูกต้องสำคัญกว่า
create or replace function sync_topic_entry_stats() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  touched  uuid[] := '{}';
  distinct_ids uuid[];
  tid uuid;
begin
  -- ต้องนับใหม่ "ทั้งเรื่องต้นทางและปลายทาง" ไม่งั้นตอนย้าย entry ข้ามเรื่อง
  -- เรื่องเดิมจะค้างตัวเลขเก่าไว้ตลอดกาล
  if TG_OP <> 'INSERT' then touched := touched || old.topic_id; end if;
  if TG_OP <> 'DELETE' then touched := touched || new.topic_id; end if;

  select array_agg(distinct v) into distinct_ids from unnest(touched) v;
  if distinct_ids is null then return null; end if;

  foreach tid in array distinct_ids loop
    update topics t
       set entry_count   = (select count(*)          from entries e
                             where e.topic_id = tid and e.deleted_at is null),
           last_entry_at = (select max(e.created_at) from entries e
                             where e.topic_id = tid and e.deleted_at is null)
     where t.id = tid;
  end loop;
  return null;
end $$;

create trigger entries_sync_stats
  after insert or update of deleted_at, topic_id or delete on entries
  for each row execute function sync_topic_entry_stats();
