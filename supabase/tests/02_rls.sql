\set ON_ERROR_STOP off
-- เตรียมข้อมูลในฐานะ superuser (bypass RLS)
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111','a@test.com'),
  ('22222222-2222-2222-2222-222222222222','b@test.com');
insert into topics (id, owner_id, title) values
  ('aaaaaaaa-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','เรื่องของ A'),
  ('bbbbbbbb-0000-0000-0000-000000000001','22222222-2222-2222-2222-222222222222','เรื่องของ B');
insert into entries (topic_id, owner_id, body) values
  ('aaaaaaaa-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','ความลับของ A'),
  ('bbbbbbbb-0000-0000-0000-000000000001','22222222-2222-2222-2222-222222222222','ความลับของ B');

\echo '=== R1: user A เห็นเฉพาะของตัวเอง (คาดหวัง 1 topic, 1 entry) ==='
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
select (select count(*) from topics) as topics_seen, (select count(*) from entries) as entries_seen;
select title from topics;

\echo '=== R2: user B เห็นเฉพาะของตัวเอง (คาดหวัง 1 topic) ==='
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select (select count(*) from topics) as topics_seen, (select count(*) from entries) as entries_seen;

\echo '=== R3: B พยายามอัปเดตเรื่องของ A (คาดหวัง 0 rows affected) ==='
update topics set title = 'โดนแฮก' where id = 'aaaaaaaa-0000-0000-0000-000000000001';

\echo '=== R4: B พยายาม insert แถวโดยสวมเป็น A (คาดหวัง FAIL: RLS with check) ==='
insert into topics (owner_id, title) values ('11111111-1111-1111-1111-111111111111','ปลอมตัว');

\echo '=== R5: B ลบ entry ของ A (คาดหวัง 0 rows affected) ==='
delete from entries where owner_id = '11111111-1111-1111-1111-111111111111';

\echo '=== R6: soft-deleted topic ต้องหายจากสายตาเจ้าของเอง ==='
reset role;
update topics set deleted_at = now() where id = 'bbbbbbbb-0000-0000-0000-000000000001';
set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select count(*) as b_topics_after_soft_delete from topics;

\echo '=== R7: anon แตะตารางไม่ได้เลย (คาดหวัง permission denied) ==='
reset role;
set role anon;
select count(*) from topics;

\echo '=== R8: anon อ่าน entries/attachments ไม่ได้ ==='
select count(*) from entries;

\echo '=== R9: link_previews — authenticated อ่านได้ แต่เขียนไม่ได้ ==='
reset role;
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
select count(*) as previews_readable from link_previews;
insert into link_previews (url_hash, url) values (repeat('b',64), 'https://x.com/');
reset role;
