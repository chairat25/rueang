# Rueang (เรื่อง) — Implementation Plan

> **ปัญหาที่แก้:** เห็นคลิปที่เที่ยวใน TikTok → กดหัวใจไว้ → พอจะไปจริงลืมว่าจะไปไหน เพราะ favorite ปนกันหมด
> **ทางแก้:** กล่องเก็บ "เรื่อง" ที่แชร์เข้ามาจากแอปได้ใน 2 แตะ + โหมดวางแผนเที่ยวที่ปลดล็อกเมื่อเรื่องนั้นเป็นทริป

- **Status:** Spec v1.1 — พร้อมส่งมอบให้ agent ลงมือทำ (ยังไม่มี application code)
- **โมเดลการทำงาน:** agent ผู้เขียน (Antigravity) ลงมือตามแผน → agent ผู้ตรวจ (Claude) audit ตาม `docs/audit-checklist.md`
- **Owner:** pond
- **สร้างเมื่อ:** 2026-09-06
- **Scale:** ใช้คนเดียว (แชร์ให้เพื่อนดูแบบอ่านอย่างเดียวได้)

---

## สารบัญ

1. [เป้าหมายและขอบเขต](#1-เป้าหมายและขอบเขต)
2. [Stack ที่เลือกใช้](#2-stack-ที่เลือกใช้)
3. [สถาปัตยกรรม Core + Kit](#3-สถาปัตยกรรม-core--kit)
4. [Data Model](#4-data-model)
5. [Security & RLS](#5-security--rls)
6. [Capture Flow (Share Target)](#6-capture-flow-share-target)
7. [Travel Kit](#7-travel-kit)
8. [การแชร์ให้เพื่อนดู](#8-การแชร์ให้เพื่อนดู)
9. [โครงสร้างโฟลเดอร์](#9-โครงสร้างโฟลเดอร์)
10. [แผนงานรายเฟส](#10-แผนงานรายเฟส)
11. [กลยุทธ์การเทส](#11-กลยุทธ์การเทส)
12. [ความเสี่ยงและทางรับมือ](#12-ความเสี่ยงและทางรับมือ)
13. [Decision Log](#13-decision-log)
14. [การส่งมอบให้ agent ลงมือทำ](#14-การส่งมอบให้-agent-ลงมือทำ)

---

## 1. เป้าหมายและขอบเขต

### 1.1 User Story หลัก

```
ในฐานะคนที่เห็นคลิปที่เที่ยวแล้วอยากเก็บไว้
ฉันอยากแชร์คลิปนั้นเข้าเรื่องที่ถูกต้องได้ทันทีจาก TikTok
เพื่อที่ตอนจะไปเที่ยวจริง ฉันเปิดเรื่องเดียวแล้วเจอทุกอย่างที่เคยเก็บไว้
```

### 1.2 สิ่งที่ระบบต้องทำได้ (Functional)

| # | ความสามารถ | เฟส |
|---|---|---|
| F1 | สร้าง/แก้/ลบ **เรื่อง** ได้ไม่จำกัดจำนวน แต่ละเรื่องมีชื่อ คำอธิบาย แท็ก | P1 |
| F2 | เพิ่ม **entry** ในเรื่อง — เป็นข้อความล้วน / ลิงก์ล้วน / ไฟล์ล้วน / ผสมกันก็ได้ | P1 |
| F3 | แนบไฟล์ได้หลายไฟล์ต่อ 1 entry (รูป, PDF, วิดีโอสั้น) | P1 |
| F4 | ค้นหาข้ามเรื่องด้วยคำ (ไทย+อังกฤษ) | P1 |
| F5 | แชร์ลิงก์จากแอปอื่น (TikTok/IG/YouTube) เข้าแอปเราได้โดยตรง | P2 |
| F6 | ดึง title/รูป/caption ของลิงก์อัตโนมัติ | P2 |
| F7 | ระบบทักว่า "เรื่องนี้ดูเหมือนทริป" จาก wording — **แต่ผู้ใช้กดเปิดเอง** | P3 |
| F8 | โหมดวางแผนเที่ยว: itinerary รายวัน + งบ + checklist | P3 |
| F9 | แชร์เรื่องเป็นลิงก์อ่านอย่างเดียวให้เพื่อน | P4 |

### 1.3 สิ่งที่ระบบต้องเป็น (Non-functional)

| # | ข้อกำหนด | ตัววัด |
|---|---|---|
| N1 | เก็บของต้องเร็วกว่ากดหัวใจใน TikTok ไม่มาก | จากกด Share → เซฟเสร็จ **≤ 2 แตะ, ≤ 5 วินาที** |
| N2 | มือถือเป็นหลัก | ออกแบบ mobile-first, ทดสอบที่ 390×844 เป็น baseline |
| N3 | ข้อมูลส่วนตัวต้องไม่รั่ว | RLS ทุกตาราง, bucket เป็น private เสมอ, ไม่มี policy ให้ `anon` |
| N4 | รองรับภาษาไทยเต็มรูปแบบ | ฟอนต์ไทย, ค้นหาไทยได้, คำเตือน/error เป็นไทย |
| N5 | ค่าใช้จ่ายต่ำ | อยู่ใน free tier ของ Vercel + Supabase |
| N6 | คุณภาพโค้ด | test coverage ≥ 80%, ไฟล์ ≤ 800 บรรทัด, ฟังก์ชัน ≤ 50 บรรทัด |

### 1.4 นอกขอบเขต (Out of scope — อย่าเผลอทำ)

- ❌ แอป native (iOS/Android) — ใช้ PWA
- ❌ ระบบ collaborate แก้ร่วมกัน / comment / real-time
- ❌ ดาวน์โหลดวิดีโอ TikTok มาเก็บ (ผิด ToS + ค่า storage)
- ❌ AI สรุป/แนะนำที่เที่ยว (P5+ ถ้าอยากได้จริงค่อยว่ากัน)
- ❌ แผนที่/เส้นทางจริง (Google Maps API) — เก็บไว้ P5
- ❌ Offline-first sync แบบเต็มรูปแบบ — P4 ทำแค่ read cache

---

## 2. Stack ที่เลือกใช้

**สรุปคำตอบ: ของที่คุณใช้อยู่ (Supabase / Next.js / Postgres / yarn) เอามาใช้ได้ทั้งหมด และเป็นชุดที่เหมาะกับโจทย์นี้ที่สุดสำหรับทีมเล็ก**

| ชั้น | เลือก | ทำไม |
|---|---|---|
| Framework | **Next.js 16.x (App Router) + TypeScript strict** | Server Actions ตัดงานเขียน REST layer ทิ้งได้ทั้งชั้น, PWA/manifest ทำได้ในตัว, deploy Vercel ฟรี |
| Database | **Postgres ผ่าน Supabase** | RLS ทำให้ authorization อยู่ที่ชั้น DB — ปลอดภัยกว่าเช็คใน app อย่างเดียว |
| Auth | **Supabase Auth** (Google OAuth + Magic link) | ไม่ต้องเขียน auth เอง |
| File storage | **Supabase Storage** (private bucket) | อยู่ใน project เดียวกับ DB, มี signed URL |
| Package manager | **yarn** | ตามที่ใช้อยู่ |
| Styling | **Tailwind CSS + shadcn/ui** | ต่อยอดความรู้จาก PitBox ได้ |
| Validation | **Zod** | schema เดียวใช้ทั้ง server action + form + parse ข้อมูลนอก |
| Client state | **TanStack Query** | cache + optimistic update ตอนลาก stop เข้าวัน |
| Drag & drop | **@dnd-kit/core** | ลาก entry ลง itinerary, รองรับ touch + keyboard (a11y) |
| Unit/Integration test | **Vitest + Testing Library** | เร็ว, ใช้ config เดียวกับ Vite |
| E2E test | **Playwright** | ทดสอบ share flow บน mobile viewport ได้ |
| Lint/Format | **ESLint + Prettier** | |
| CI | **GitHub Actions** | lint → typecheck → test → build |
| Deploy | **Vercel** (app) + **Supabase Cloud** (DB/Storage) | |

**สิ่งที่ตั้งใจ "ไม่" ใช้:**

- ไม่ใช้ ORM (Prisma/Drizzle) — ใช้ `supabase-js` + SQL migration ตรงๆ เพราะ RLS เป็นพระเอก และ ORM จะบังคับให้ bypass RLS ด้วย service role มากเกินจำเป็น
- ไม่ใช้ state manager แยก (Redux/Zustand) — TanStack Query + URL state พอ
- ไม่ใช้ LLM ในการ detect ทริป — ดูเหตุผลที่ [D-04](#13-decision-log)

> ⚠️ Next.js 16 มี breaking changes จาก 15 (async params/searchParams, caching defaults) — **ก่อนเขียนโค้ดให้อ่าน `node_modules/next/dist/docs/` ในโปรเจกต์จริงก่อน** และ pin เวอร์ชันแบบ exact ใน `package.json`

---

## 3. สถาปัตยกรรม Core + Kit

หัวใจของการ "flex เรื่องได้" คือ **แกนกลางต้องไม่รู้จักคำว่าเที่ยว**

```
┌──────────────────────────── CORE (ทุกเรื่องมีเหมือนกัน) ─────────────────────────────┐
│                                                                                      │
│   Topic (เรื่อง)                                                                      │
│     ├── Entry ──┬── body: ข้อความ (ว่างได้)                                            │
│     │           ├── links[]  ──> LinkPreview (cache กลาง, dedupe ด้วย url hash)        │
│     │           └── files[]  ──> Supabase Storage (private bucket)                    │
│     └── tags[]                                                                        │
│                                                                                       │
└───────────────────────────────────────┬──────────────────────────────────────────────┘
                                        │ เสียบเพิ่มได้ (opt-in)
        ┌───────────────────────────────┴───────────────────────────────┐
        │                    KIT: Travel (P3)                            │
        │   Trip ─┬── TripDay[] ── TripStop[]  (อ้าง Entry ต้นทางกลับได้)  │
        │         ├── ChecklistItem[]                                     │
        │         └── BudgetItem[]                                        │
        └────────────────────────────────────────────────────────────────┘

        ┌────────────────────────────────────────────────────────────────┐
        │   KIT อื่นในอนาคต (ยังไม่ทำ) — ซื้อของ / เรียน / รีวิว          │
        │   เพิ่ม kit = เพิ่มตารางใหม่ + route ใหม่ ไม่ต้องแตะ core เลย     │
        └────────────────────────────────────────────────────────────────┘
```

**กฎเหล็กของสถาปัตยกรรมนี้ (ห้ามละเมิด):**

1. ตาราง/โค้ดใน core **ห้ามมีคอลัมน์หรือ import ที่เจาะจงเรื่องเที่ยว** — ยกเว้น `topics.is_travel_enabled` ซึ่งเป็นแค่สวิตช์เปิด/ปิด kit
2. Kit **อ้าง core ได้** (`trip_stops.entry_id → entries.id`) แต่ core **ห้ามอ้าง kit**
3. ปิด kit = ซ่อน UI **ไม่ลบข้อมูล** — เปิดกลับมาต้องได้ของเดิมครบ
4. โค้ดของ kit อยู่ใน `features/travel/` ทั้งก้อน ลบทิ้งทั้งโฟลเดอร์แล้วแอปต้องยัง build ผ่าน (ยกเว้น route ที่ import เข้ามา)

### Data flow

```
[Browser/PWA]
     │
     ├─(1) อ่านข้อมูลของตัวเอง ──> supabase-js (anon key + JWT ผู้ใช้) ──> Postgres RLS
     │
     ├─(2) เขียนข้อมูล / งานที่ต้อง validate ──> Server Action ──> Zod ──> supabase-js (ผูก session ผู้ใช้)
     │
     ├─(3) ดึง link preview ──> Route Handler /api/link-preview ──> SSRF guard ──> oEmbed/OG
     │                                                                    │
     │                                                          service role เขียน cache
     │
     └─(4) หน้าแชร์สาธารณะ /s/[slug] ──> Server Component ──> service role + เช็ค is_public
```

**หลักการ:** อ่าน = client ตรงผ่าน RLS (เร็ว), เขียน = Server Action (validate ได้), งานที่ต้อง bypass RLS = route ฝั่ง server เท่านั้น และต้องเช็คสิทธิ์เองแบบชัดเจนทุกครั้ง

---

## 4. Data Model

### 4.1 ERD

```
auth.users ──1:1── profiles
     │
     └──1:N── topics ──┬──1:N── entries ──┬──1:N── entry_links ──N:1── link_previews
                       │                   └──1:N── attachments
                       │
                       └──1:1── trips ──┬──1:N── trip_days ──1:N── trip_stops
                                        ├──1:N── checklist_items
                                        └──1:N── budget_items
```

> 📁 **SQL ทั้งหมดในหัวข้อนี้เขียนเป็นไฟล์จริงไว้แล้วที่ `supabase/migrations/`**
> agent ผู้เขียนแค่รัน ไม่ต้องพิมพ์ใหม่ และ **ห้ามแก้** (ดู AGENTS.md ข้อ H1)
> เนื้อหาข้างล่างคือสำเนาไว้อ่านประกอบ ถ้าไม่ตรงกับไฟล์จริง **ให้ยึดไฟล์จริง**

### 4.2 Migration `0001_core.sql`

```sql
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
```

**ลำดับการเขียนที่ FK บังคับไว้:** `entry_links.url_hash` อ้าง `link_previews(url_hash)` แบบ `on delete restrict` แปลว่า **ต้อง upsert แถว `link_previews` (status `pending`) ให้เสร็จก่อน** แล้วค่อย insert `entry_links` เสมอ

⚠️ **`link_previews` เขียนด้วย client ของผู้ใช้ไม่ได้** — ตารางนี้ไม่มี RLS policy สำหรับ insert/update ให้ `authenticated` (ยืนยันด้วยเทส R9 ใน `supabase/tests/02_rls.sql`) ดังนั้นใน `createEntry` ต้องทำสองจังหวะ:

1. upsert `link_previews` ผ่าน **admin client (service role)** — แถวนี้เป็น metadata สาธารณะ ไม่มีข้อมูลส่วนตัว
2. insert `entries` + `entry_links` ผ่าน **client ของผู้ใช้** ให้ RLS ทำงานตามปกติ

**ทำไมไม่เปิดให้ผู้ใช้เขียนเอง:** cache นี้ใช้ร่วมกันทุกคน ถ้าผู้ใช้ insert คู่ `url_hash`/`url` ที่ไม่ตรงกันได้ จะกลายเป็น cache poisoning ที่ผู้ใช้คนอื่นเห็น preview ผิด

สองจังหวะนี้ไม่ atomic (คนละ client) แต่ปลอดภัย — ถ้าจังหวะ 2 พัง จะเหลือแถว `pending` กำพร้าซึ่งไม่มีผลอะไร และห้ามลบแถว `link_previews` ที่ยังมีคนอ้างอยู่

**หมายเหตุ constraint ที่บังคับใน DB ไม่ได้:**
`entry` ต้องมีอย่างน้อยหนึ่งอย่าง (body / link / file) — เช็คข้าม 3 ตารางใน `CHECK` ไม่ได้ จึงบังคับที่ **Zod schema ในชั้น service** (`createEntrySchema.refine(...)`) และมี unit test คุมไว้ ห้าม insert entry เปล่าผ่านทางอื่น

### 4.3 Migration `0002_travel_kit.sql`

```sql
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
```

**ทำไม `owner_id` ซ้ำอยู่ทุกตาราง:** เพื่อให้ RLS policy เป็น `owner_id = auth.uid()` ตรงๆ ไม่ต้อง `EXISTS` ไล่ join กลับไป `topics` ทุก query — เร็วกว่าและอ่านง่ายกว่ามาก ราคาที่จ่ายคือต้องมี trigger กันการเซ็ตผิดเจ้าของ (อยู่ใน `0003_rls.sql`)

---

## 5. Security & RLS

### 5.1 หลักการ

| หลัก | รายละเอียด |
|---|---|
| Deny by default | เปิด RLS ทุกตาราง แล้วค่อยเพิ่ม policy ทีละอัน |
| **ไม่มี policy ให้ `anon` เลย** | หน้าแชร์สาธารณะ render ฝั่ง server ด้วย service role — ป้องกันการไล่ query หา public topic ทั้งหมดผ่าน PostgREST |
| Service role ใช้เฉพาะ server | `SUPABASE_SERVICE_ROLE_KEY` อยู่ใน `env.server.ts` ที่ import `server-only` เท่านั้น |
| Bucket private เสมอ | ไม่มีการตั้ง bucket เป็น public ในทุกกรณี |
| Validate ที่ boundary | ทุก Server Action / Route Handler เริ่มด้วย `schema.parse()` |

### 5.2 Migration `0003_rls.sql`

```sql
-- ============================================================================
-- Rueang · 0003_rls.sql
-- Row Level Security — deny by default
--
-- กฎเหล็ก 2 ข้อของไฟล์นี้ (ห้ามละเมิด):
--   1) ห้ามสร้าง policy ให้ role `anon` เด็ดขาด
--      หน้าแชร์สาธารณะ /s/[slug] render ฝั่ง server ด้วย service role
--      ถ้าเปิดให้ anon อ่านได้ จะไล่ query หา public topic ของคนอื่นทั้งระบบผ่าน PostgREST
--   2) ทุกตารางลูกใช้ policy เดียวกันคือ owner_id = auth.uid()
--      ความถูกต้องของ owner_id ค้ำด้วย trigger enforce_parent_owner() ท้ายไฟล์
-- ============================================================================

alter table profiles        enable row level security;
alter table topics          enable row level security;
alter table entries         enable row level security;
alter table entry_links     enable row level security;
alter table attachments     enable row level security;
alter table link_previews   enable row level security;
alter table trips           enable row level security;
alter table trip_days       enable row level security;
alter table trip_stops      enable row level security;
alter table checklist_items enable row level security;
alter table budget_items    enable row level security;

-- ── profiles ────────────────────────────────────────────────────────────────
create policy profiles_self_select on profiles
  for select to authenticated using (id = auth.uid());
create policy profiles_self_update on profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- ── topics ──────────────────────────────────────────────────────────────────
-- soft-delete ต้องถูกซ่อนตั้งแต่ชั้น DB ไม่ใช่แค่ใน query ของ app
create policy topics_owner_select on topics
  for select to authenticated using (owner_id = auth.uid() and deleted_at is null);
create policy topics_owner_insert on topics
  for insert to authenticated with check (owner_id = auth.uid());
create policy topics_owner_update on topics
  for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy topics_owner_delete on topics
  for delete to authenticated using (owner_id = auth.uid());

-- ── entries ─────────────────────────────────────────────────────────────────
create policy entries_owner_select on entries
  for select to authenticated using (owner_id = auth.uid() and deleted_at is null);
create policy entries_owner_insert on entries
  for insert to authenticated with check (owner_id = auth.uid());
create policy entries_owner_update on entries
  for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy entries_owner_delete on entries
  for delete to authenticated using (owner_id = auth.uid());

-- ── ตารางลูกที่เหลือ: owner-only ทุก operation ───────────────────────────────
create policy entry_links_owner on entry_links
  for all to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy attachments_owner on attachments
  for all to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy trips_owner on trips
  for all to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy trip_days_owner on trip_days
  for all to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy trip_stops_owner on trip_stops
  for all to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy checklist_items_owner on checklist_items
  for all to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy budget_items_owner on budget_items
  for all to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- ── link_previews ───────────────────────────────────────────────────────────
-- metadata สาธารณะของหน้าเว็บ ไม่มีข้อมูลส่วนตัว → ผู้ใช้ที่ login แล้วอ่านได้ทุกคน
-- เขียนได้เฉพาะ service role (ตั้งใจไม่ให้ policy insert/update กับ authenticated)
create policy link_previews_read on link_previews
  for select to authenticated using (true);

-- ============================================================================
-- Trigger กันปลอมเจ้าของ / กันผูกข้ามบัญชี
--
-- RLS การันตีแค่ว่า "แถวใหม่ owner_id = ตัวเรา" แต่ไม่ได้ห้ามเราสร้าง entry
-- ที่ topic_id ชี้ไปหาเรื่องของคนอื่น (RLS ไม่ตรวจ FK) — trigger นี้ปิดช่องนั้น
-- ============================================================================

create or replace function enforce_parent_owner() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  parent_table   text := TG_ARGV[0];
  fk_column      text := TG_ARGV[1];
  parent_pk      text := TG_ARGV[2];
  require_active boolean := TG_ARGV[3] = '1';
  fk_value uuid;
  old_fk   uuid;
  extra_cond text := '';
  is_ok boolean;
begin
  fk_value := (to_jsonb(new) ->> fk_column)::uuid;
  if fk_value is null then
    return new;                            -- FK ที่ nullable (เช่น day_id, entry_id)
  end if;

  -- ตรวจเฉพาะตอน "ตั้งค่า FK ใหม่" หรือ "ย้าย FK" เท่านั้น
  -- ถ้าตรวจทุก UPDATE จะพังตอน soft-delete หรือแก้แถวที่ FK ชี้ไปหาของที่ถูก soft-delete ไปแล้ว
  -- (เช่น แก้ชื่อ trip_stop หลังลบ entry ต้นทาง — ซึ่งดีไซน์ตั้งใจให้ทำได้)
  if TG_OP = 'UPDATE' then
    old_fk := (to_jsonb(old) ->> fk_column)::uuid;
    if old_fk is not distinct from fk_value then
      return new;
    end if;
  end if;

  if require_active then
    extra_cond := ' and p.deleted_at is null';
  end if;

  execute format(
    'select exists (select 1 from %I p where p.%I = $1 and p.owner_id = $2%s)',
    parent_table, parent_pk, extra_cond
  ) into is_ok using fk_value, new.owner_id;

  if not is_ok then
    raise exception '% ที่อ้างถึงไม่มีอยู่ หรือไม่ใช่ของเจ้าของคนเดียวกัน (%=%)',
      parent_table, fk_column, fk_value
      using errcode = '42501';
  end if;

  return new;
end $$;

revoke execute on function enforce_parent_owner() from public;

-- core
create trigger entries_parent_guard      before insert or update on entries
  for each row execute function enforce_parent_owner('topics','topic_id','id','1');
create trigger entry_links_parent_guard  before insert or update on entry_links
  for each row execute function enforce_parent_owner('entries','entry_id','id','1');
create trigger attachments_topic_guard   before insert or update on attachments
  for each row execute function enforce_parent_owner('topics','topic_id','id','1');
create trigger attachments_entry_guard   before insert or update on attachments
  for each row execute function enforce_parent_owner('entries','entry_id','id','1');

-- travel kit
create trigger trips_parent_guard          before insert or update on trips
  for each row execute function enforce_parent_owner('topics','topic_id','id','1');
create trigger trip_days_parent_guard      before insert or update on trip_days
  for each row execute function enforce_parent_owner('trips','topic_id','topic_id','0');
create trigger trip_stops_parent_guard     before insert or update on trip_stops
  for each row execute function enforce_parent_owner('trips','topic_id','topic_id','0');
create trigger trip_stops_day_guard        before insert or update on trip_stops
  for each row execute function enforce_parent_owner('trip_days','day_id','id','0');
create trigger trip_stops_entry_guard      before insert or update on trip_stops
  for each row execute function enforce_parent_owner('entries','entry_id','id','1');
create trigger checklist_items_parent_guard before insert or update on checklist_items
  for each row execute function enforce_parent_owner('trips','topic_id','topic_id','0');
create trigger budget_items_parent_guard    before insert or update on budget_items
  for each row execute function enforce_parent_owner('trips','topic_id','topic_id','0');

-- ============================================================================
-- Storage: bucket 'topic-files' (private เสมอ)
-- path = {owner_id}/{topic_id}/{uuid}.{ext}
-- ============================================================================

insert into storage.buckets (id, name, public, file_size_limit)
values ('topic-files', 'topic-files', false, 26214400)
on conflict (id) do nothing;

create policy topic_files_read on storage.objects
  for select to authenticated
  using (bucket_id = 'topic-files' and (storage.foldername(name))[1] = auth.uid()::text);

create policy topic_files_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'topic-files' and (storage.foldername(name))[1] = auth.uid()::text);

create policy topic_files_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'topic-files' and (storage.foldername(name))[1] = auth.uid()::text);

-- ============================================================================
-- Grants — ระบุให้ชัดเจน ไม่ฝากความปลอดภัยไว้กับ default privileges ของ Supabase
--
-- ชั้นที่ 1: anon ไม่มีสิทธิ์แตะตารางใน public เลย (ต่อให้เผลอเพิ่ม policy ก็ยังเข้าไม่ได้)
-- ชั้นที่ 2: authenticated มีสิทธิ์ระดับตาราง แต่ RLS เป็นตัวกรองว่าเห็นแถวไหน
-- ============================================================================

grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;

revoke all on all tables in schema public from anon;

-- ตารางที่จะถูกสร้างเพิ่มทีหลัง (0004+) ต้องได้สิทธิ์แบบเดียวกันโดยอัตโนมัติ
-- ไม่งั้นตารางใหม่จะเข้าถึงไม่ได้ หรือแย่กว่านั้นคือเผลอเปิดให้ anon
alter default privileges in schema public grant select, insert, update, delete on tables to authenticated;
alter default privileges in schema public revoke all on tables from anon;
```

### 5.3 Storage policy

Bucket: **`topic-files`** (private)
Path pattern: **`{owner_id}/{topic_id}/{uuid}.{ext}`**

```sql
create policy "own folder read" on storage.objects
  for select to authenticated
  using (bucket_id = 'topic-files' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "own folder write" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'topic-files' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "own folder delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'topic-files' and (storage.foldername(name))[1] = auth.uid()::text);
```

### 5.4 SSRF guard (สำคัญที่สุดในระบบนี้)

`/api/link-preview` รับ URL จากภายนอกมา fetch — เป็นช่องโหว่ SSRF คลาสสิก **ต้องผ่านด่านทุกข้อก่อน fetch:**

```
validateUrl(input):
  1. parse ได้ และ protocol ∈ {http:, https:}          ไม่ผ่าน → reject
  2. hostname ไม่ใช่ localhost / *.local / metadata.*   ไม่ผ่าน → reject
  3. resolve DNS → IP ทุกตัวต้องไม่อยู่ใน private range  ไม่ผ่าน → reject
     (10/8, 172.16/12, 192.168/16, 127/8, 169.254/16, ::1, fc00::/7)
  4. ต่อด้วย fetch: redirect: 'manual', ตาม redirect เองไม่เกิน 3 ชั้น
     และ re-validate ปลายทางทุกครั้ง
  5. timeout 5s, อ่าน body ไม่เกิน 512KB, ต้องเป็น text/html หรือ json
  6. rate limit ต่อ user: 30 req/min
```

**ห้ามข้ามข้อ 3 และ 4 เด็ดขาด** — validate ครั้งเดียวตอนแรกแล้วปล่อยตาม redirect คือช่องโหว่ที่ยังเปิดอยู่

---

## 6. Capture Flow (Share Target)

### 6.1 เป้าหมาย

```
TikTok  ──Share──>  [Rueang]  ──>  /share
                                     │
                          ┌──────────┴──────────┐
                          │  ดึง preview ทันที   │  (ระหว่างนี้แสดง skeleton)
                          └──────────┬──────────┘
                                     ▼
                    ┌────────────────────────────────┐
                    │  🎬 [รูป]  ชื่อคลิป...            │
                    │                                 │
                    │  เก็บเข้าเรื่อง:                  │
                    │  [เชียงใหม่ 🏔] [คาเฟ่ ☕] [+ ใหม่] │  ← แตะ 1 ครั้ง = เซฟเลย
                    └────────────────────────────────┘
```

**แตะที่ 1** = เลือกแอปเราจาก share sheet · **แตะที่ 2** = เลือกเรื่อง → เซฟทันที ไม่มีปุ่ม confirm

### 6.2 `public/manifest.json`

```json
{
  "name": "Rueang",
  "short_name": "เรื่อง",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#0f1115",
  "theme_color": "#0f1115",
  "icons": [
    { "src": "/icons/192.png", "sizes": "192x192", "type": "image/png" },
    { "src": "/icons/512.png", "sizes": "512x512", "type": "image/png" },
    { "src": "/icons/maskable.png", "sizes": "512x512", "type": "image/png", "purpose": "maskable" }
  ],
  "share_target": {
    "action": "/share",
    "method": "GET",
    "params": { "title": "title", "text": "text", "url": "url" }
  }
}
```

### 6.3 กับดักที่ต้องระวัง (จากพฤติกรรมจริงของแอป)

| กับดัก | ทางแก้ |
|---|---|
| **TikTok มักส่ง URL มาใน `text` ไม่ใช่ `url`** และมีข้อความพ่วง เช่น `"ดูคลิปนี้สิ https://vt.tiktok.com/xxx/ ..."` | `extractUrl(params)` ต้องดู `url` ก่อน แล้ว fallback ไป regex หา URL ตัวแรกใน `text` และ `title` |
| TikTok ให้ลิงก์ย่อ `vt.tiktok.com` ต้อง redirect ก่อน | ตาม redirect (สูงสุด 3 ชั้น) + re-validate ทุกชั้น ตาม §5.4 |
| URL มี tracking param (`?_r=1&_t=...`) → cache miss ทุกครั้ง | `normalizeUrl()` ตัด param ที่ขึ้นต้นด้วย `utm_`, `_` และ `is_from_webapp`, `sender_device` ก่อนคำนวณ hash |
| **iOS/Safari ไม่รองรับ Web Share Target** | แจก **iOS Shortcut**: Share Sheet → รับ URL → เปิด `https://<app>/share?url=<encoded>` — เป็นงานตั้งค่า ไม่ใช่โค้ด ทำเอกสารไว้ที่ `docs/ios-shortcut.md` |
| ผู้ใช้ยังไม่ได้ login ตอนแชร์ | `/share` เก็บ params ไว้ใน `sessionStorage` → เด้งไป login → กลับมาที่ `/share` พร้อมของเดิม **ห้ามทำ params หาย** |
| ดึง preview ไม่สำเร็จ | เซฟลิงก์ดิบไว้ก่อนพร้อม status `failed` + ปุ่ม "ลองใหม่" — **ห้ามบล็อกการเซฟ** และห้ามกลืน error เงียบๆ (log ฝั่ง server ทุกครั้ง) |

### 6.4 แชร์ไฟล์ (เลื่อนไป P4)

`method: "POST"` + `enctype: multipart/form-data` จำเป็นสำหรับการแชร์รูป/วิดีโอ แต่ต้องมี Service Worker คอยดัก POST navigation แล้วพักไฟล์ไว้ใน Cache API ก่อน redirect — ซับซ้อนกว่ามาก **P2 ทำ GET ให้เสร็จก่อน** แล้วค่อยเพิ่ม POST ทีหลังโดยไม่กระทบของเดิม

---

## 7. Travel Kit

### 7.1 ตัวตรวจจับ (`lib/travel/detect-travel-intent.ts`)

**ต้องเป็น pure function ไม่มี I/O ไม่เรียก API** → เทสง่าย ฟรี เร็ว และผลลัพธ์เหมือนเดิมทุกครั้ง

```ts
export type TravelSignal = {
  readonly score: number;
  readonly matchedTerms: readonly string[];
  readonly shouldSuggest: boolean;
};

export function detectTravelIntent(text: string): TravelSignal;
```

> 📁 **รายการคำเต็ม (77 จังหวัด + ต่างประเทศ + ทุกกลุ่ม) อยู่ที่ `docs/travel-wordlists.md`** พร้อมกับดัก "เลย" ที่เป็นทั้งจังหวัดและคำวิเศษณ์

**น้ำหนักคำ:**

| น้ำหนัก | กลุ่ม | ตัวอย่าง |
|---|---|---|
| **3** | คำบอกทริปตรงๆ | เที่ยว, ทริป, ไปเที่ยว, แพลนเที่ยว, itinerary, trip, vacation, travel |
| **2** | ชื่อสถานที่ | 77 จังหวัดไทย + ประเทศ/เมืองยอดฮิต (ญี่ปุ่น, โตเกียว, เกาหลี, ฮอกไกโด, เวียดนาม…) |
| **2** | ประเภทจุดหมาย | คาเฟ่, ที่พัก, โรงแรม, รีสอร์ท, ทะเล, เกาะ, ภูเขา, น้ำตก, วัด, ตลาด, ดำน้ำ, แคมป์ปิ้ง |
| **1** | คำแวดล้อม | พิกัด, วิว, ที่กิน, ร้านเด็ด, ราคา, จอง, เช็คอิน |

**เกณฑ์:** `shouldSuggest = score >= 4` — ตั้งใจให้ต้องเจอสัญญาณอย่างน้อย 2 กลุ่ม กันการทักมั่ว
(เช่น "ทริปเชียงใหม่" = 3+2 = 5 ✅ ทัก · "คาเฟ่ใกล้บ้าน" = 2 ❌ ไม่ทัก · "ที่พักหัวหิน" = 2+2 = 4 ✅ ทัก)

**Input ที่ป้อนให้ detector:** `title + description + tags + body ของ entry 5 อันล่าสุด` — รันใหม่ทุกครั้งที่แก้ชื่อเรื่องหรือเพิ่ม entry

### 7.2 พฤติกรรม UX (สำคัญ — ตรงตามที่ตกลงกัน)

```
score >= 4  และยัง is_travel_enabled = false  และยังไม่เคยปฏิเสธ
        │
        ▼
┌──────────────────────────────────────────────────────┐
│ 🧳 เรื่องนี้ดูเหมือนทริปนะ (เจอคำว่า: ทริป, เชียงใหม่)   │
│    เปิดโหมดวางแผนเที่ยวมั้ย?                          │
│                          [ เปิดเลย ]  [ ไม่ต้อง ]      │
└──────────────────────────────────────────────────────┘
```

- ✅ **ไม่เปิดเองอัตโนมัติ** ไม่ว่าคะแนนจะสูงแค่ไหน
- ✅ กด "ไม่ต้อง" → `travel_suggestion_dismissed = true` **ไม่ทักอีกเลยสำหรับเรื่องนี้**
- ✅ เปิดเองได้ตลอดจากเมนู `⋯ → เปิดโหมดวางแผนเที่ยว` แม้ระบบไม่เคยทัก
- ✅ บอกเหตุผลที่ทักเสมอ (`matchedTerms`) — ผู้ใช้ต้องเข้าใจว่าทำไมถึงเด้ง

### 7.3 หน้าวางแผน (`/topics/[id]/plan`)

```
┌─ ทริปเชียงใหม่ ────────── 12–15 ต.ค. · งบ 8,500 / 12,000 ฿ ─┐
│                                                              │
│  ┌── 📦 กองรอจัด (5) ──────────────────────────────────────┐  │
│  │  [คาเฟ่ริมน้ำ] [ดอยอินทนนท์] [ร้านข้าวซอย] …            │  │  ← entry ที่เก็บไว้แต่ยังไม่รู้จะไปวันไหน
│  └─────────────────────────────────────────────────────────┘  │
│                                                              │
│  ── วันที่ 1 · 12 ต.ค. ─────────────────────────────────    │
│     09:00  ☕ คาเฟ่ริมน้ำ          90 นาที   ~250 ฿   [ที่มา]  │
│     11:00  🏔 ดอยอินทนนท์         4 ชม.    ~600 ฿           │
│     + เพิ่มจุดแวะ                                            │
│                                                              │
│  ── วันที่ 2 · 13 ต.ค. ─────────────────────────────────    │
│     ...                                                      │
│                                                              │
│  [ 📋 ของที่ต้องเตรียม 4/9 ]   [ 💰 งบ ]                      │
└──────────────────────────────────────────────────────────────┘
```

**พฤติกรรมสำคัญ:**
- ลาก stop จาก "กองรอจัด" ลงวันได้ (dnd-kit, รองรับทั้ง touch และคีย์บอร์ด)
- ทุก stop กด `[ที่มา]` กลับไปดู entry เดิมพร้อมคลิป/รูปได้ — **นี่คือจุดที่แก้ปัญหา "ลืมว่าจะไปไหน" จริงๆ**
- ลบ entry ต้นทาง → stop ยังอยู่ (`on delete set null`) แค่ปุ่ม "ที่มา" หายไป
- งบรวม = `sum(budget_items.amount)` + `sum(trip_stops.est_cost)` เทียบกับ `budget_total`
- ปิดโหมด → ซ่อนแท็บ Plan แต่ **ข้อมูลอยู่ครบ** เปิดกลับได้เหมือนเดิม

---

## 8. การแชร์ให้เพื่อนดู

```
เจ้าของกด "แชร์"
   → gen share_slug = nanoid(16) ตัวพิมพ์เล็ก+ตัวเลข (เดาไม่ได้)
   → is_public = true
   → ได้ลิงก์ https://<app>/s/<slug>

เพื่อนเปิดลิงก์ (ไม่ต้อง login)
   → Server Component ดึงด้วย service role: where share_slug = ? and is_public and deleted_at is null
   → ถ้าไม่เจอ → 404 (ห้ามบอกว่า "เคยมีแต่ปิดไปแล้ว" — ไม่ปล่อยข้อมูลรั่วผ่าน error)
   → render อ่านอย่างเดียว: entry + ข้อความ + link preview + รูป (signed URL อายุ 10 นาที)
```

**กฎเหล็ก:**
- **slug ต้องตรง `^[a-z0-9]{12,24}$` ที่ DB บังคับไว้** — `nanoid()` ค่าเริ่มต้นมีตัวพิมพ์ใหญ่กับ `-` `_` ซึ่งจะโดน CHECK constraint ตีกลับ ต้องใช้ `customAlphabet('0123456789abcdefghijklmnopqrstuvwxyz', 16)`
- ไม่มี RLS policy ให้ `anon` แม้แต่ตัวเดียว → ต่อให้ anon key หลุด ก็ query อะไรไม่ได้
- signed URL สร้างฝั่ง server **หลัง** ยืนยันว่า topic นั้น `is_public` แล้วเท่านั้น
- `noindex` ใน meta ของหน้า `/s/[slug]` — ลิงก์แชร์ไม่ควรโผล่ Google
- ปิดแชร์ = `is_public = false` (เก็บ slug ไว้ เปิดใหม่ได้ลิงก์เดิม) + ปุ่ม "สร้างลิงก์ใหม่" ที่ rotate slug ทิ้งของเก่า

---

## 9. โครงสร้างโฟลเดอร์

ยึด **ไฟล์เล็กเยอะๆ ดีกว่าไฟล์ใหญ่ไม่กี่ไฟล์** และ **จัดตาม feature ไม่ใช่ตามชนิดไฟล์**

```
rueang/
├── app/
│   ├── (auth)/login/page.tsx
│   ├── (app)/
│   │   ├── layout.tsx                  # shell + bottom nav
│   │   ├── page.tsx                    # รายการเรื่องทั้งหมด
│   │   ├── search/page.tsx
│   │   └── topics/[id]/
│   │       ├── page.tsx                # ฟีด entry
│   │       ├── settings/page.tsx
│   │       └── plan/page.tsx           # travel kit (guard ด้วย is_travel_enabled)
│   ├── share/page.tsx                  # ปลายทาง share target
│   ├── s/[slug]/page.tsx               # หน้าสาธารณะ (service role)
│   └── api/link-preview/route.ts
│
├── features/
│   ├── topics/       { components/ actions.ts queries.ts schema.ts }
│   ├── entries/      { components/ actions.ts queries.ts schema.ts }
│   ├── attachments/  { components/ actions.ts upload-client.ts schema.ts }
│   ├── capture/      { components/ extract-url.ts normalize-url.ts }
│   ├── travel/       { components/ actions.ts queries.ts schema.ts }   ← ลบทั้งโฟลเดอร์แล้วแอปต้องยัง build ผ่าน
│   └── sharing/      { components/ actions.ts }
│
├── lib/
│   ├── supabase/     { client.ts server.ts admin.ts middleware.ts }
│   ├── travel/       { detect-travel-intent.ts wordlists/{strong,places,kinds,weak}.ts }
│   ├── url/          { normalize.ts hash.ts ssrf-guard.ts }
│   ├── link-preview/ { fetch-preview.ts providers/{tiktok,youtube,generic}.ts cache.ts }
│   ├── env.ts        # public env (Zod, fail-fast)
│   └── env.server.ts # server-only env (import 'server-only')
│
├── components/ui/                      # shadcn primitives
├── supabase/migrations/*.sql
├── tests/{unit,integration,e2e}/
├── docs/{ios-shortcut.md,adr/}
├── .env.example
└── implementplan.md
```

**เพดานที่ห้ามทะลุ:** ไฟล์ ≤ 800 บรรทัด (ปกติ 200–400) · ฟังก์ชัน ≤ 50 บรรทัด · ซ้อน if ไม่เกิน 4 ชั้น (ใช้ early return)

---

## 10. แผนงานรายเฟส

> **ทุกเฟสทำแบบ TDD:** เขียนเทสให้แดงก่อน → เขียนโค้ดให้เขียว → refactor → เช็ค coverage
> **ทุกเฟสจบด้วย code review** (`code-reviewer` และถ้าแตะ auth/upload/URL ต้องผ่าน `security-reviewer` ด้วย)

---

### P0 · Foundation

**เป้าหมาย:** โครงพร้อม deploy ได้ ยังไม่มีฟีเจอร์ให้ผู้ใช้

| # | งาน | ผลลัพธ์ |
|---|---|---|
| P0-1 | `yarn create next-app` (TS, App Router, Tailwind, ESLint) + pin เวอร์ชันแบบ exact | `package.json` |
| P0-2 | ตั้ง Supabase project + `yarn add @supabase/supabase-js @supabase/ssr` | คีย์อยู่ใน `.env.local` |
| P0-3 | `lib/env.ts` + `lib/env.server.ts` — parse ด้วย Zod, **fail-fast ตอน build ถ้าคีย์ขาด** | `.env.example` commit ได้ |
| P0-4 | `lib/supabase/{client,server,admin,middleware}.ts` — `admin.ts` ต้องมี `import 'server-only'` บรรทัดแรก | |
| P0-5 | Migration `0001_core.sql` + `0002_travel_kit.sql` | รันบน local + cloud ผ่าน |
| P0-6 | Migration `0003_rls.sql` — policy ครบทุกตาราง + trigger กันปลอมเจ้าของ | |
| P0-7 | สร้าง bucket `topic-files` (private) + storage policy | |
| P0-8 | Supabase Auth: Google OAuth + magic link, middleware refresh session, protected routes | `/login` ใช้ได้ |
| P0-9 | Design tokens + ฟอนต์ไทย (IBM Plex Sans Thai / Noto Sans Thai) + shadcn init + dark-first | |
| P0-10 | Vitest + Playwright + GitHub Actions (`lint → typecheck → test → build`) | CI เขียว |
| P0-11 | Deploy Vercel + ต่อ Supabase cloud | เปิด URL จริงได้ |

**DoD:**
- [ ] CI เขียวทั้ง pipeline
- [ ] **เทส RLS ผ่าน:** สร้าง user A และ B → A `select` ข้อมูลของ B ได้ **0 แถว** ทุกตาราง (ไม่ใช่ error — ต้องได้ 0 แถว)
- [ ] `.env.local` หายแล้ว build ต้องพังพร้อม error ที่บอกชัดว่าขาดตัวไหน
- [ ] `grep -r "SERVICE_ROLE" app/ features/ components/` ต้องไม่เจอนอก `lib/supabase/admin.ts`

---

### P1 · MVP — ใช้งานได้จริงตั้งแต่เฟสนี้ ⭐

**เป้าหมาย:** เก็บของได้ครบทุกแบบ หาเจอ — ถึงจะยังต้อง copy ลิงก์มาวางเอง

| # | งาน | ผลลัพธ์ |
|---|---|---|
| P1-1 | `features/topics/schema.ts` — Zod ของ topic (create/update/archive) | เทสก่อน |
| P1-2 | Server Actions: `createTopic` / `updateTopic` / `archiveTopic` / `softDeleteTopic` | |
| P1-3 | หน้ารายการเรื่อง: การ์ด + จำนวน entry + เวลาเพิ่มล่าสุด + สร้างเรื่องใหม่ | `/` |
| P1-4 | `features/entries/schema.ts` — **`.refine()` บังคับว่า entry ต้องมีอย่างน้อย body หรือ link หรือ file** | เทสเคสเปล่าต้องพัง |
| P1-5 | Server Actions: `createEntry` / `updateEntry` / `deleteEntry` (soft delete) | |
| P1-6 | Entry composer: กล่องข้อความ + วางลิงก์ + แนบไฟล์ **ในฟอร์มเดียว** ไม่ต้องเลือกชนิดก่อน | |
| P1-7 | Upload flow: server action ออก signed upload URL (เช็ค mime/ขนาด/โควตา) → client PUT → server action ยืนยันแล้ว insert แถว | ไม่มีไฟล์กำพร้า |
| P1-8 | แสดงไฟล์แนบ: รูป lazy + lightbox, ไฟล์อื่นเป็น chip ดาวน์โหลด (signed URL 10 นาที) | |
| P1-9 | ฟีด entry ในเรื่อง: เรียงใหม่→เก่า, infinite scroll, แก้/ลบ inline | `/topics/[id]` |
| P1-10 | ค้นหา: `pg_trgm` + `unaccent` ครอบ `topics.title`, `entries.title/body` — คืนผลข้ามเรื่องพร้อมชื่อเรื่อง | `/search` |
| P1-11 | Trigger อัปเดต `entry_count` และ `last_entry_at` | เทสว่าเลขตรงหลังลบ |
| P1-12 | Empty state / loading skeleton / error boundary ทุกหน้า **เป็นภาษาไทย** | |

**DoD:**
- [ ] เก็บ entry 3 แบบได้จริง: ข้อความล้วน · ไฟล์ล้วน · ข้อความ+ลิงก์+ไฟล์ 2 ไฟล์
- [ ] ค้นหาคำไทยเจอ (เทสด้วย "คาเฟ่", "เชียงใหม่")
- [ ] อัปโหลดไฟล์ 30MB ต้องถูกปฏิเสธพร้อมข้อความไทยที่บอกลิมิต ไม่ใช่ error ดิบ
- [ ] Coverage ≥ 80%
- [ ] **ใช้เองจริง 3 วัน** เก็บอย่างน้อย 10 entry ก่อนขึ้น P2

---

### P2 · Capture — แก้ปัญหาต้นเรื่อง 🎯

**เป้าหมาย:** แชร์จาก TikTok เข้าเรื่องได้ใน 2 แตะ

| # | งาน | ผลลัพธ์ |
|---|---|---|
| P2-1 | `lib/url/normalize.ts` — ตัด tracking param, lowercase host, ตัด trailing slash | pure fn + เทส |
| P2-2 | `lib/url/hash.ts` — sha256 ของ URL ที่ normalize แล้ว | |
| P2-3 | `lib/url/ssrf-guard.ts` — ครบทั้ง 6 ข้อใน §5.4 **รวม re-validate ทุก redirect** | เทสด้วย IP ส่วนตัว/localhost/redirect ไป 169.254.169.254 |
| P2-4 | `lib/link-preview/providers/tiktok.ts` — oEmbed `https://www.tiktok.com/oembed?url=` | |
| P2-5 | provider `youtube` (oEmbed) + `generic` (parse OG tags) | |
| P2-6 | `/api/link-preview` — cache-first จาก `link_previews`, rate limit 30/นาที/user, เก็บ `failed` พร้อมเหตุผล | |
| P2-7 | `features/capture/extract-url.ts` — ดู `url` → `text` → `title` ตามลำดับ ด้วย regex | **เทสด้วยรูปแบบที่ TikTok ส่งมาจริง** |
| P2-8 | `manifest.json` + ไอคอน + `<link rel="manifest">` | ติดตั้งเป็น PWA ได้ |
| P2-9 | `/share` — preview + ชิปเรื่องล่าสุด 6 อัน + ปุ่มสร้างเรื่องใหม่, **แตะชิป = เซฟทันที** | |
| P2-10 | เคสยังไม่ login: เก็บ params ลง `sessionStorage` → login → กลับมาต่อโดยของไม่หาย | E2E คุม |
| P2-11 | การ์ด link preview ในฟีด: รูป + title + provider + ปุ่ม "ลองใหม่" ถ้า `failed` | |
| P2-12 | `docs/ios-shortcut.md` + Shortcut พร้อมใช้ | |

**DoD:**
- [ ] Android: แชร์จาก TikTok → เซฟเข้าเรื่อง ครบใน **2 แตะ**
- [ ] iOS: ผ่าน Shortcut ทำได้แบบเดียวกัน
- [ ] ลิงก์ย่อ `vt.tiktok.com` ดึง preview ได้ถูกต้อง
- [ ] **เทส SSRF ผ่านหมด** — private IP, localhost, redirect ไป metadata endpoint ต้องถูกบล็อกทุกเคส
- [ ] preview พังแล้วยังเซฟลิงก์ได้ และเห็นสถานะชัดว่าพัง

---

### P3 · Travel Kit 🧳

| # | งาน | ผลลัพธ์ |
|---|---|---|
| P3-1 | `lib/travel/wordlists/*.ts` — strong / places (77 จังหวัด + เมืองนอกยอดฮิต) / kinds / weak | ข้อมูลล้วน ไม่มี logic |
| P3-2 | `detect-travel-intent.ts` — pure function ให้คะแนน + คืน `matchedTerms` | **เทสก่อนเขียน ≥ 20 เคส** |
| P3-3 | เรียก detector ตอนสร้าง/แก้เรื่อง และตอนเพิ่ม entry | |
| P3-4 | แบนเนอร์แนะนำ + ปุ่มเปิด/ไม่ต้อง + จำการปฏิเสธ | |
| P3-5 | สวิตช์เปิด/ปิดโหมดเองในหน้า settings ของเรื่อง | |
| P3-6 | `enableTravelKit` action — สร้างแถว `trips` (+ วันตามช่วงวันที่ถ้ามี) แบบ idempotent | เปิดซ้ำต้องไม่สร้างซ้ำ |
| P3-7 | หน้า `/topics/[id]/plan` — กองรอจัด + วันเป็นคอลัมน์/สแต็ก | |
| P3-8 | สร้าง stop จาก entry ที่มีอยู่ (ปุ่ม "ใส่ในแผน" บนการ์ด entry) | |
| P3-9 | ลากจัดวันด้วย dnd-kit + optimistic update + **รองรับคีย์บอร์ด** | |
| P3-10 | Checklist: เพิ่ม/ติ๊ก/ลบ/จัดเรียง + แสดง 4/9 | |
| P3-11 | งบ: budget items + รวมกับ `est_cost` ของ stop เทียบ `budget_total` | เทสการคำนวณ |
| P3-12 | ปิดโหมด = ซ่อนอย่างเดียว | เทสว่าเปิดกลับได้ข้อมูลครบ |

**DoD:**
- [ ] สร้างเรื่อง "ทริปเชียงใหม่" → **ระบบทัก แต่ยังไม่เปิดให้**
- [ ] สร้างเรื่อง "ร้านกาแฟใกล้บ้าน" → **ไม่ทัก**
- [ ] กด "ไม่ต้อง" แล้วรีเฟรช → ไม่ทักซ้ำ
- [ ] จัด 3 วัน 8 จุด แล้วงบรวมถูกต้อง
- [ ] ปิดแล้วเปิดใหม่ → itinerary ครบเหมือนเดิม
- [ ] `rm -rf features/travel/` แล้ว `yarn build` พังเฉพาะไฟล์ route ที่ import — ไม่ลามไป core

---

### P4 · Share + ขัดเงา

| # | งาน |
|---|---|
| P4-1 | `share_slug` gen (nanoid 16) + toggle `is_public` + ปุ่ม rotate slug |
| P4-2 | `/s/[slug]` — Server Component, service role, `noindex`, 404 แบบไม่รั่วข้อมูล |
| P4-3 | signed URL สำหรับไฟล์ในหน้าสาธารณะ (อายุ 10 นาที, ออกหลังเช็ค `is_public`) |
| P4-4 | Export เรื่องเป็น Markdown + zip ไฟล์แนบ |
| P4-5 | Service Worker: cache หน้า/รูปที่เคยเปิด → เปิดดูแผนตอนเน็ตไม่ดีได้ |
| P4-6 | Share Target แบบ POST + รับไฟล์ (§6.4) |
| P4-7 | ถังขยะ: กู้เรื่อง/entry ที่ soft delete ภายใน 30 วัน + cron ลบจริง — **ตอนลบจริงต้องลบ object ใน Storage ด้วย** (`on delete cascade` ลบแค่แถว `attachments` ไม่ได้แตะไฟล์ → ไม่ทำ = ไฟล์ค้างกินโควตาถาวร) |
| P4-8 | รอบขัดเงา: a11y (contrast, focus ring, screen reader), Lighthouse ≥ 90 ทุกหมวด |

**DoD:**
- [ ] เพื่อนเปิดลิงก์แชร์ในเครื่องที่ไม่ได้ login แล้วเห็นเนื้อหา + รูปครบ
- [ ] ปิดแชร์แล้วลิงก์เดิมได้ 404 ทันที
- [ ] เปิด DevTools ที่หน้า `/s/[slug]` แล้ว **หา service role key ไม่เจอ**

---

## 11. กลยุทธ์การเทส

**เป้า coverage ≥ 80%** · โครงสร้างเทสแบบ Arrange-Act-Assert · ชื่อเทสบอกพฤติกรรม ไม่ใช่ชื่อฟังก์ชัน

| ชั้น | เครื่องมือ | คุมอะไร |
|---|---|---|
| **Unit** | Vitest | `detectTravelIntent`, `normalizeUrl`, `extractUrl`, SSRF guard, คำนวณงบ, Zod schema |
| **Integration** | Vitest + Supabase local | Server Actions, **RLS แยกผู้ใช้**, trigger นับ entry, upload flow |
| **E2E** | Playwright (mobile viewport) | login → สร้างเรื่อง → แชร์ลิงก์เข้า → เปิดโหมดเที่ยว → จัดแผน → แชร์ให้เพื่อน |

### เทสที่ห้ามขาด

```ts
// lib/travel/detect-travel-intent.test.ts
test('ทักเมื่อเจอคำบอกทริปคู่กับชื่อจังหวัด', () => {})
test('ไม่ทักเมื่อเจอแค่คำแวดล้อมคำเดียว', () => {})
test('คืนคำที่ตรงกลับมาเพื่อบอกเหตุผลกับผู้ใช้', () => {})
test('ไม่ทักกับเรื่องที่ไม่เกี่ยวกับเที่ยวเลย', () => {})

// features/capture/extract-url.test.ts
test('ดึง URL จาก text ได้เมื่อ TikTok ไม่ส่ง field url มา', () => {})
test('เลือก url field ก่อน text เสมอเมื่อมีทั้งคู่', () => {})
test('คืน null เมื่อไม่มี URL ใน payload เลย', () => {})

// lib/url/ssrf-guard.test.ts
test('ปฏิเสธ hostname ที่ resolve เป็น private IP', () => {})
test('ปฏิเสธเมื่อ redirect ไปยัง private IP แม้ปลายทางแรกจะปลอดภัย', () => {})
test('ปฏิเสธ protocol ที่ไม่ใช่ http/https', () => {})

// tests/integration/rls.test.ts
test('ผู้ใช้ A อ่านเรื่องของผู้ใช้ B ได้ 0 แถว', () => {})
test('ผู้ใช้ A สร้าง entry ใน topic ของ B ไม่ได้', () => {})
test('anon key query ตาราง topics ได้ 0 แถวเสมอ', () => {})
```

---

## 12. ความเสี่ยงและทางรับมือ

| # | ความเสี่ยง | ระดับ | ทางรับมือ |
|---|---|---|---|
| R1 | **iOS ไม่รองรับ Web Share Target** — ทำให้ friction กลับมาสูง | 🔴 สูง | แจก iOS Shortcut ตั้งแต่ P2 และเทสจริงบนเครื่อง iOS ก่อนปิดเฟส ถ้ายังฝืด ค่อยพิจารณา Capacitor wrapper ใน P5 |
| R2 | **SSRF จาก `/api/link-preview`** | 🔴 สูง | §5.4 ครบทุกข้อ + `security-reviewer` ต้องผ่านก่อน merge P2 |
| R3 | TikTok เปลี่ยน/ปิด oEmbed | 🟡 กลาง | provider แยกไฟล์ + fallback ไป OG tags + สุดท้าย fallback เป็นลิงก์ดิบ (เซฟได้เสมอ) |
| R4 | Storage 1GB เต็ม | 🟡 กลาง | บีบรูปฝั่ง client ก่อนอัป (max 1600px, WebP), ลิมิต 25MB/ไฟล์, แสดงโควตาที่ใช้ไปในหน้า settings |
| R5 | ทัก "น่าจะเป็นทริป" พลาดจนน่ารำคาญ | 🟡 กลาง | threshold 4 ตั้งใจให้ conservative + จำการปฏิเสธ + ปรับ wordlist ได้เพราะเป็นไฟล์ข้อมูลล้วน |
| R6 | Next.js 16 breaking changes | 🟡 กลาง | pin exact version, อ่าน `node_modules/next/dist/docs/` ก่อนเขียน, ไม่อัปเวอร์ชันกลางเฟส |
| R7 | **ทำไปแล้วไม่ได้ใช้เอง** (เสี่ยงที่สุดจริงๆ) | 🔴 สูง | P1 ต้องใช้งานได้จริงและ **ใช้เอง 3 วันก่อนขึ้น P2** — ถ้าไม่อยากใช้ ให้กลับมาแก้ P1 อย่าไปต่อ |
| R8 | ลิงก์แชร์หลุดออกไปโดยไม่ตั้งใจ | 🟢 ต่ำ | slug เดาไม่ได้ + `noindex` + ปุ่ม rotate slug + ปิดแชร์ได้ทันที |

---

## 13. Decision Log

| # | เรื่อง | ตัดสินใจ | เหตุผล |
|---|---|---|---|
| D-01 | โครงสร้างข้อมูล | **Core + Kit** (ไม่ใช่ block-based แบบ Notion, ไม่ใช่แยกตารางตามประเภทเรื่อง) | ยืดหยุ่นพอที่จะเพิ่ม kit ใหม่โดยไม่แตะ core แต่ไม่ over-engineer สำหรับผู้ใช้ไม่กี่คน (YAGNI) |
| D-02 | Entry มีชนิดมั้ย | **ไม่มี** — entry = body ว่างได้ + links[] + files[] | ตรงกับที่ผู้ใช้บอกว่า "บางอันมีทั้งข้อความและแนบไฟล์" ผู้ใช้ไม่ต้องเลือกชนิดก่อนพิมพ์ |
| D-03 | Share Target method | **GET ก่อน (P2), POST ทีหลัง (P4)** | GET ไม่ต้องใช้ Service Worker และพอสำหรับลิงก์ TikTok — ตัดความซับซ้อนก้อนใหญ่ออกจากเส้นทางวิกฤต |
| D-04 | ตรวจจับทริป | **rule-based ล้วน ไม่ใช้ LLM** | deterministic → unit test ได้ตรงๆ, ฟรี, ตอบทันที, อธิบายเหตุผลกับผู้ใช้ได้ว่าเจอคำไหน |
| D-05 | เปิดโหมดเที่ยวอัตโนมัติมั้ย | **ไม่ — แค่ทัก ผู้ใช้กดเอง** | ตามที่ผู้ใช้ระบุตรงๆ และการเปิดผิดสร้างความรำคาญมากกว่าประโยชน์ |
| D-06 | หน้าแชร์สาธารณะ | **service role ฝั่ง server ไม่มี RLS policy ให้ `anon`** | ถ้าเปิด policy ให้ anon จะไล่ query หา public topic ของคนอื่นทั้งระบบได้ผ่าน PostgREST |
| D-07 | ORM | **ไม่ใช้** — `supabase-js` + SQL migration ตรงๆ | RLS เป็นกลไกความปลอดภัยหลัก ORM มักผลักให้ใช้ service role จนความปลอดภัยหลุด |
| D-08 | `owner_id` ซ้ำในตารางลูก | **denormalize** + trigger กันปลอม | RLS policy เป็น `owner_id = auth.uid()` ตรงๆ ไม่ต้อง join ทุก query |
| D-09 | ค้นหาภาษาไทย | **`pg_trgm` + `unaccent`** ไม่ใช้ full-text search | Postgres ไม่มี stemmer ภาษาไทย trigram ทำงานกับไทยได้ดีกว่าและพอสำหรับข้อมูลระดับนี้ |
| D-10 | ลบข้อมูล | **soft delete** (`deleted_at`) ทั้ง topic และ entry | ผู้ใช้เก็บของสะสมมานาน ลบพลาดแล้วกู้ไม่ได้คือความเสียหายที่ยอมรับไม่ได้ |
| D-11 | แผนที่/เส้นทาง | **เลื่อนออกจาก MVP** | ต้องใช้ Google Maps API key + billing + งานเพิ่มเยอะ ขณะที่ปัญหาจริงคือ "จำไม่ได้ว่าจะไปไหน" ไม่ใช่ "ไปยังไง" |

---

---

## 14. การส่งมอบให้ agent ลงมือทำ

### 14.1 ของที่ส่งมอบแล้ว (agent ไม่ต้องคิดเอง)

| ไฟล์ | คืออะไร | agent ทำอะไรกับมัน |
|---|---|---|
| `implementplan.md` | แผนงานทั้งหมด (ไฟล์นี้) | อ่าน แล้วทำตาม §10 ทีละ task — **ห้ามแก้** |
| `AGENTS.md` | กติกาการเขียนโค้ด + ข้อห้าม 10 ข้อ | อ่านก่อนแตะโค้ดบรรทัดแรก |
| `supabase/migrations/0001_core.sql` | schema แกนกลาง | รัน — **ห้ามแก้** |
| `supabase/migrations/0002_travel_kit.sql` | schema travel kit | รัน — **ห้ามแก้** |
| `supabase/migrations/0003_rls.sql` | RLS + trigger + storage policy | รัน — **ห้ามแก้** |
| `.env.example` | รายการ env ที่ต้องมี | คัดลอกเป็น `.env.local` แล้วเติมค่า |
| `docs/travel-wordlists.md` | wordlist เต็ม + กติกาให้คะแนน | transcribe ลง `lib/travel/wordlists/*.ts` |
| `docs/audit-checklist.md` | เกณฑ์ที่จะถูกตรวจ | อ่านไว้ให้รู้ว่าอะไรจะโดนตรวจ |

**ทำไม schema/RLS ถึง freeze:** ถ้าปล่อยให้ agent ออกแบบ schema เอง งาน audit จะกลายเป็นการเถียงกันว่าอะไรถูก แทนที่จะตรวจว่าโค้ดตรงสเปกมั้ย — พอ schema ตายตัว การตรวจก็เหลือแค่ "ตรงหรือไม่ตรง"

### 14.2 วงจรงานต่อ 1 เฟส

```
   ┌─────────────────────────────────────────────────────────────┐
   │  agent ผู้เขียน                                              │
   │    1. อ่าน implementplan.md §10 เฟส P<n> + AGENTS.md         │
   │    2. TDD ทีละ task (แดง → เขียว → refactor)                 │
   │    3. yarn verify เขียว + coverage >= 80%                    │
   │    4. เช็ค DoD ของเฟสครบทุกข้อ                                │
   │    5. commit + หยุด รายงานว่าทำอะไรไปบ้าง                     │
   └────────────────────────────┬────────────────────────────────┘
                                ▼
   ┌─────────────────────────────────────────────────────────────┐
   │  agent ผู้ตรวจ (audit)                                       │
   │    6. รันหมวด A (ทุกเฟส) + หมวดของเฟสนั้นใน audit-checklist  │
   │    7. ออกรายงานตามรูปแบบท้าย checklist พร้อมหลักฐานที่รันจริง │
   └────────────────────────────┬────────────────────────────────┘
                                ▼
              🔴 CRITICAL เหลืออยู่? ──ใช่──> ส่งกลับให้แก้ วนข้อ 2
                                │
                               ไม่
                                ▼
                      เจ้าของโปรเจกต์อนุมัติ → ขึ้นเฟสถัดไป
```

### 14.3 กติกาของ agent ผู้เขียน

- ทำทีละเฟส **จบเฟสแล้วหยุด** อย่าทำต่อไปเฟสถัดไปเอง
- เจอแผนขัดกันเอง / schema ดูผิด → **หยุดแล้วถาม** ห้ามเดาแล้วเขียนต่อ ห้ามแก้ migration เอง
- ห้ามทำของที่อยู่ในรายการ "นอกขอบเขต" (§1.4) แม้จะดูง่ายและ "น่าจะมีประโยชน์"
- รายงานตอนจบเฟสต้องบอก **สิ่งที่ทำไม่สำเร็จหรือข้ามไป** ด้วยเสมอ ไม่ใช่รายงานแต่ของที่เสร็จ

### 14.4 กติกาของ agent ผู้ตรวจ

- **ไม่เชื่อคำรายงาน เชื่อผลรัน** — ทุก finding ต้องมีเอาต์พุตคำสั่งจริงหรือเลขบรรทัดกำกับ
- ตรวจไม่ได้ให้เขียนว่า "ตรวจไม่ได้ เพราะ..." **ห้ามเขียนว่าผ่าน**
- แยก "ผิดสเปก" ออกจาก "ไม่ถูกใจผู้ตรวจ" — อย่างหลังเป็น ⚪ LOW เท่านั้น
- โฟกัส 🔴 CRITICAL ก่อนเสมอ: RLS รั่ว · service role หลุด · SSRF · ไฟล์สาธารณะ · เปิดโหมดเที่ยวเอง · ปิดโหมดแล้วข้อมูลหาย

---

## ขั้นตอนถัดไป

1. `git init` แล้ว commit สเปกทั้งหมดไว้เป็น baseline
   (commit สเปกไว้ก่อน จะได้ `git diff` ตรวจได้ว่า agent ไปแก้ migration ที่ freeze ไว้หรือเปล่า)
2. สร้าง Supabase project แล้วเติมค่าใน `.env.local`
3. ส่ง repo นี้ให้ agent ผู้เขียน สั่งว่า: *"อ่าน AGENTS.md แล้วทำ P0 ใน implementplan.md §10 ให้จบ แล้วหยุด"*
4. P0 เสร็จ → audit ตาม `docs/audit-checklist.md` หมวด A + B
5. ผ่านแล้วค่อยสั่ง P1 — วนแบบนี้ทุกเฟส

> **จุดที่ห้ามลืม:** เป้าหมายของโปรเจกต์นี้คือ *"พอจะไปเที่ยวจริงแล้วเปิดมาเจอทุกอย่าง"* — ทุกครั้งที่ลังเลว่าจะทำฟีเจอร์ไหน ให้ถามว่ามันทำให้ **เก็บง่ายขึ้น** หรือ **หาเจอง่ายขึ้น** มั้ย ถ้าไม่ใช่ทั้งสองอย่าง ให้เลื่อนออกไป
