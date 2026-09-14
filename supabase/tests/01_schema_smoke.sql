\set ON_ERROR_STOP off
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111','a@test.com'),
  ('22222222-2222-2222-2222-222222222222','b@test.com');

insert into topics (id, owner_id, title) values
  ('aaaaaaaa-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','ทริปเชียงใหม่'),
  ('bbbbbbbb-0000-0000-0000-000000000001','22222222-2222-2222-2222-222222222222','เรื่องของ B');

\echo '--- T1: profile ถูกสร้างอัตโนมัติจาก trigger'
select count(*) as profiles_created from profiles;

\echo '--- T2: A สร้าง entry ใน topic ตัวเอง = ต้องสำเร็จ'
insert into entries (id, topic_id, owner_id, body) values
  ('cccccccc-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111','คาเฟ่ริมน้ำ');

\echo '--- T3: A สร้าง entry ใน topic ของ B = ต้อง FAIL (42501)'
insert into entries (topic_id, owner_id, body) values
  ('bbbbbbbb-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','แอบยัด');

\echo '--- T4: entry_count ต้อง = 1'
select title, entry_count, last_entry_at is not null as has_last from topics
 where id = 'aaaaaaaa-0000-0000-0000-000000000001';

\echo '--- T5: entry_links ก่อนมี link_preview = ต้อง FAIL (FK restrict)'
insert into entry_links (entry_id, owner_id, url, url_hash) values
  ('cccccccc-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111',
   'https://vt.tiktok.com/x/', repeat('a',64));

\echo '--- T6: upsert link_preview ก่อน แล้วค่อย entry_links = ต้องสำเร็จ'
insert into link_previews (url_hash, url, status) values (repeat('a',64),'https://vt.tiktok.com/x/','pending');
insert into entry_links (entry_id, owner_id, url, url_hash) values
  ('cccccccc-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111',
   'https://vt.tiktok.com/x/', repeat('a',64));
select count(*) as links from entry_links;

\echo '--- T7: soft delete entry -> entry_count กลับเป็น 0'
update entries set deleted_at = now() where id = 'cccccccc-0000-0000-0000-000000000001';
select entry_count from topics where id = 'aaaaaaaa-0000-0000-0000-000000000001';
update entries set deleted_at = null where id = 'cccccccc-0000-0000-0000-000000000001';

\echo '--- T8: เปิด travel kit ของ A'
insert into trips (topic_id, owner_id, start_date, end_date)
 values ('aaaaaaaa-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','2026-10-12','2026-10-15');
insert into trip_days (id, topic_id, owner_id, day_index, date) values
 ('dddddddd-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000001',
  '11111111-1111-1111-1111-111111111111',1,'2026-10-12');

\echo '--- T9: stop ที่ day_id ว่าง (กองรอจัด) = ต้องสำเร็จ'
insert into trip_stops (topic_id, owner_id, name) values
 ('aaaaaaaa-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','ยังไม่รู้จะไปวันไหน');

\echo '--- T10: B แอบใส่ stop ใน trip ของ A = ต้อง FAIL'
insert into trip_stops (topic_id, owner_id, name) values
 ('aaaaaaaa-0000-0000-0000-000000000001','22222222-2222-2222-2222-222222222222','แอบยัด');

\echo '--- T11: end_date < start_date = ต้อง FAIL'
insert into trips (topic_id, owner_id, start_date, end_date)
 values ('bbbbbbbb-0000-0000-0000-000000000001','22222222-2222-2222-2222-222222222222','2026-10-15','2026-10-12');

\echo '--- T12: is_public = true แต่ไม่มี slug = ต้อง FAIL'
update topics set is_public = true where id = 'aaaaaaaa-0000-0000-0000-000000000001';

\echo '--- T13: is_public + slug ถูกต้อง = ต้องสำเร็จ'
update topics set is_public = true, share_slug = 'abc123def456' where id = 'aaaaaaaa-0000-0000-0000-000000000001';
select is_public, share_slug from topics where id = 'aaaaaaaa-0000-0000-0000-000000000001';

\echo '--- T14: ลบ entry จริง -> trip_stops.entry_id ต้องเป็น null ไม่ใช่ stop หาย'
insert into trip_stops (id, topic_id, owner_id, entry_id, name) values
 ('eeeeeeee-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000001',
  '11111111-1111-1111-1111-111111111111','cccccccc-0000-0000-0000-000000000001','คาเฟ่ริมน้ำ');
delete from entries where id = 'cccccccc-0000-0000-0000-000000000001';
select name, entry_id is null as entry_cleared from trip_stops where id = 'eeeeeeee-0000-0000-0000-000000000001';

\echo '--- T15: RLS เปิดครบทุกตาราง'
select count(*) filter (where not rowsecurity) as tables_without_rls from pg_tables where schemaname='public';

\echo '--- T16: ต้องไม่มี policy ให้ anon เลย'
select count(*) as anon_policies from pg_policies where schemaname='public' and 'anon' = any(roles);

\echo '--- T17: ย้าย entry ข้ามเรื่อง -> entry_count ต้องถูกทั้งเรื่องต้นทางและปลายทาง'
insert into topics (id, owner_id, title) values
  ('aaaaaaaa-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111','เรื่องปลายทาง');
insert into entries (id, topic_id, owner_id, body) values
  ('cccccccc-0000-0000-0000-000000000002','aaaaaaaa-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111','จะถูกย้าย');
select title, entry_count from topics
 where id in ('aaaaaaaa-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000002') order by title;
update entries set topic_id = 'aaaaaaaa-0000-0000-0000-000000000002'
 where id = 'cccccccc-0000-0000-0000-000000000002';
\echo '    หลังย้าย: ต้นทางต้องลด ปลายทางต้องเพิ่ม (ถ้าต้นทางไม่ลด = บั๊ก)'
select title, entry_count from topics
 where id in ('aaaaaaaa-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000002') order by title;

\echo '--- T18: แก้ trip_stop ได้ แม้ entry ต้นทางถูก soft-delete ไปแล้ว (ต้องสำเร็จ)'
insert into entries (id, topic_id, owner_id, body) values
  ('cccccccc-0000-0000-0000-000000000003','aaaaaaaa-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111','ต้นทางของ stop');
insert into trip_stops (id, topic_id, owner_id, entry_id, name) values
  ('eeeeeeee-0000-0000-0000-000000000002','aaaaaaaa-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111','cccccccc-0000-0000-0000-000000000003','จุดแวะ');
update entries set deleted_at = now() where id = 'cccccccc-0000-0000-0000-000000000003';
update trip_stops set name = 'จุดแวะ (แก้ชื่อ)' where id = 'eeeeeeee-0000-0000-0000-000000000002';
select name from trip_stops where id = 'eeeeeeee-0000-0000-0000-000000000002';

\echo '--- T19: ย้าย stop ไปหา entry ของคนอื่น = ต้อง FAIL (guard ยังทำงานตอน FK เปลี่ยน)'
insert into entries (id, topic_id, owner_id, body) values
  ('cccccccc-0000-0000-0000-000000000004','bbbbbbbb-0000-0000-0000-000000000001',
   '22222222-2222-2222-2222-222222222222','ของ B');
update trip_stops set entry_id = 'cccccccc-0000-0000-0000-000000000004'
 where id = 'eeeeeeee-0000-0000-0000-000000000002';

\echo '--- T20: soft-delete topic แล้ว soft-delete entry ตาม = ต้องสำเร็จ (cascade ของ app)'
update topics  set deleted_at = now() where id = 'aaaaaaaa-0000-0000-0000-000000000002';
update entries set deleted_at = now() where topic_id = 'aaaaaaaa-0000-0000-0000-000000000002';
select count(*) as entries_soft_deleted from entries
 where topic_id = 'aaaaaaaa-0000-0000-0000-000000000002' and deleted_at is not null;
