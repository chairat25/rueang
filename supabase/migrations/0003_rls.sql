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
