# Schema tests — พิสูจน์ว่า migration ทำงานจริง

สคริปต์ชุดนี้ **รันแล้วผ่านจริงแล้ว** ตอนเขียนสเปก (PostgreSQL 15)
ใช้เป็นเครื่องมือของ agent ผู้ตรวจ (`docs/audit-checklist.md` หมวด B) และใช้ยืนยันซ้ำได้ทุกเมื่อ

| ไฟล์ | ตรวจอะไร |
|---|---|
| `00_stub_supabase.sql` | สร้าง `auth.users`, `auth.uid()`, `storage.*`, role `anon/authenticated/service_role` — **ใช้เฉพาะตอนเทสบน Postgres เปล่า** ไม่ต้องรันบน Supabase จริง |
| `01_schema_smoke.sql` | constraint + trigger 16 ข้อ: กันผูกข้ามบัญชี, counter, FK ordering ของ link_previews, soft delete, `is_public` ต้องมี slug, ลบ entry แล้ว stop ต้องอยู่ต่อ |
| `02_rls.sql` | RLS จริงด้วยการสวม role: A/B เห็นแยกกัน, update/delete ข้ามเจ้าของได้ 0 แถว, insert สวมรอยถูกปฏิเสธ, **anon โดน permission denied ทุกตาราง** |

## รันบน Postgres เปล่า (ไม่ต้องมี Supabase)

```bash
PGBIN=/opt/homebrew/opt/postgresql@15/bin
DATA=$(mktemp -d)/pgdata

$PGBIN/initdb -D "$DATA" -U postgres --auth=trust
$PGBIN/pg_ctl -D "$DATA" -o "-p 55432 -h 127.0.0.1 -c unix_socket_directories=''" -l /tmp/pg.log start

PSQL="$PGBIN/psql -h 127.0.0.1 -p 55432 -U postgres"
$PSQL -c "create database rueang_test"
$PSQL -d rueang_test -c "create extension if not exists pgcrypto"

for f in supabase/tests/00_stub_supabase.sql supabase/migrations/000*.sql; do
  $PSQL -d rueang_test -v ON_ERROR_STOP=1 -q -f "$f" && echo "ok $f"
done

$PSQL -d rueang_test -f supabase/tests/01_schema_smoke.sql
$PSQL -d rueang_test -f supabase/tests/02_rls.sql

$PGBIN/pg_ctl -D "$DATA" stop && rm -rf "$DATA"
```

## วิธีอ่านผล

สคริปต์ตั้งใจให้ **มี ERROR โผล่ในบางข้อ** เพราะกำลังทดสอบว่า "สิ่งที่ควรถูกห้าม ถูกห้ามจริง"
อ่านที่บรรทัด `\echo` เหนือแต่ละข้อว่าคาดหวังอะไร:

- ข้อที่เขียนว่า **"ต้อง FAIL"** → ต้องเห็น `ERROR:` **ถ้าไม่เห็น = ช่องโหว่**
- ข้อที่เขียนว่า **"ต้องสำเร็จ"** → ต้องเห็น `INSERT 1` / ตัวเลขที่ถูกต้อง

ผลที่ควรได้ (ยืนยันแล้ว):
`R1/R2 = 1 แถวต่อคน` · `R3/R5 = 0 rows affected` · `R4/R9-insert = RLS violation` ·
`R6 = 0` (soft delete หายจากสายตาเจ้าของ) · `R7/R8 = permission denied` · `T15 = 0` · `T16 = 0`
