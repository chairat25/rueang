# Audit Checklist — ตรวจโค้ดที่ agent เขียนมา

> ใช้โดย agent ผู้ตรวจ (Claude) หลัง agent ผู้เขียน (Antigravity) ส่งงานแต่ละเฟส
> **หลักการ: ไม่เชื่อคำรายงาน เชื่อผลรัน** — ทุกข้อต้องมีหลักฐานเป็นเอาต์พุตคำสั่งหรือเลขบรรทัดในไฟล์

## ระดับความรุนแรง

| ระดับ | ความหมาย | ต้องทำอะไร |
|---|---|---|
| 🔴 CRITICAL | ช่องโหว่ความปลอดภัย / ข้อมูลรั่ว / ข้อมูลหาย | **บล็อก** ห้ามขึ้นเฟสถัดไปจนกว่าจะแก้ |
| 🟠 HIGH | บั๊ก หรือผิดสเปกในจุดสำคัญ | ต้องแก้ก่อนขึ้นเฟสถัดไป |
| 🟡 MEDIUM | ปัญหาการดูแลรักษาโค้ด | แก้ถ้าทำได้ |
| ⚪ LOW | สไตล์ | บันทึกไว้เฉยๆ |

---

> 🧪 **เทส schema/RLS มีให้แล้วที่ `supabase/tests/`** (รันผ่านจริงแล้วตอนเขียนสเปก)
> หมวด B ส่วนใหญ่ใช้สคริปต์ชุดนั้นตรวจได้เลย ดู `supabase/tests/README.md`

## A. ตรวจทุกเฟส (รันก่อนเสมอ)

```bash
yarn install --frozen-lockfile
yarn verify                     # lint + typecheck + test ต้องเขียวทั้งหมด
yarn test:coverage              # ต้อง >= 80%
yarn build                      # ต้องผ่าน
```

| # | ตรวจ | วิธี | ระดับถ้าพลาด |
|---|---|---|---|
| A1 | migration ที่ freeze ไว้ไม่ถูกแก้ | `git diff --stat -- supabase/migrations/000[123]_*.sql` ต้องว่าง | 🔴 |
| A2 | service role ไม่หลุดออกนอก `admin.ts` | `grep -rn "SERVICE_ROLE" app/ features/ components/ lib/ \| grep -v "lib/supabase/admin.ts"` ต้องไม่เจอ | 🔴 |
| A3 | ไม่มี env ลับที่ขึ้นต้น `NEXT_PUBLIC_` | `grep -rn "NEXT_PUBLIC_.*SERVICE\|NEXT_PUBLIC_.*SECRET" .` ต้องไม่เจอ | 🔴 |
| A4 | ไม่มี secret ค้างในโค้ด | `git log -p \| grep -iE "eyJ[A-Za-z0-9_-]{20,}\|sk-[A-Za-z0-9]{20,}"` ต้องไม่เจอ | 🔴 |
| A5 | ไม่มี `any` | `grep -rn ": any\|as any\|<any>" app/ features/ lib/` ต้องไม่เจอ | 🟠 |
| A6 | ไม่มี catch ที่กลืน error | `grep -rn -A2 "catch" app/ features/ lib/` แล้วอ่านทีละจุด — ทุก catch ต้อง log | 🟠 |
| A7 | ไม่มี `console.log` ค้าง (`console.error` ในชั้น server ได้) | `grep -rn "console\.log" app/ features/ components/` | 🟡 |
| A8 | ไฟล์ไม่เกิน 800 บรรทัด | `find app features lib components -name "*.ts*" -exec wc -l {} + \| sort -rn \| head -20` | 🟡 |
| A9 | ไม่มีการ mutate | อ่านหา `.push(`, `.sort(`, `.splice(`, `arr[i] =`, `obj.x =` บน object ที่รับเข้ามา | 🟡 |
| A10 | ข้อความ UI เป็นภาษาไทยครบ | สุ่มดู error/empty state 10 จุด | 🟡 |

---

## B. เฟส P0 — Foundation

| # | ตรวจ | เกณฑ์ผ่าน | ระดับ |
|---|---|---|---|
| B1 | **RLS แยกผู้ใช้จริง** | integration test: user A `select` ทุกตารางของ user B ได้ **0 แถว** (ไม่ใช่ error) | 🔴 |
| B2 | **anon อ่านอะไรไม่ได้** | รัน `supabase/tests/02_rls.sql` → ข้อ R7/R8 ต้องได้ `permission denied` (grant ถูก revoke ไว้) หรืออย่างน้อยต้องได้ 0 แถว | 🔴 |
| B3 | **trigger กันผูกข้ามบัญชี** | user A insert entry ที่ `topic_id` เป็นของ B → ต้อง error `42501` | 🔴 |
| B4 | RLS เปิดครบทุกตาราง | `select tablename, rowsecurity from pg_tables where schemaname='public'` → `rowsecurity = true` ทุกแถว | 🔴 |
| B5 | ไม่มี policy ให้ anon | `select * from pg_policies where schemaname='public' and 'anon' = any(roles)` → 0 แถว | 🔴 |
| B6 | bucket เป็น private | `select public from storage.buckets where id='topic-files'` → `false` | 🔴 |
| B7 | env fail-fast | ลบ `.env.local` แล้ว `yarn build` ต้องพังพร้อมบอกชื่อ env ที่ขาด ไม่ใช่ error งงๆ | 🟠 |
| B8 | `admin.ts` มี `import 'server-only'` บรรทัดแรก | อ่านไฟล์ | 🔴 |

---

## C. เฟส P1 — MVP

| # | ตรวจ | เกณฑ์ผ่าน | ระดับ |
|---|---|---|---|
| C1 | entry เปล่าสร้างไม่ได้ | เทส: ไม่มีทั้ง body/link/file → schema ต้อง reject | 🟠 |
| C2 | entry 3 แบบสร้างได้จริง | ข้อความล้วน · ไฟล์ล้วน · ข้อความ+ลิงก์+ไฟล์ 2 ไฟล์ | 🟠 |
| C3 | **ไม่มีไฟล์กำพร้า** | อัปโหลดแล้ว insert แถวพัง → ไฟล์ใน storage ต้องถูกลบตาม หรือมี job เก็บกวาด | 🟠 |
| C4 | ลิมิตขนาดไฟล์บังคับ **ฝั่ง server** | ปลอม request 30MB ตรงไป server action → ต้องถูกปฏิเสธ (ไม่ใช่เช็คแค่ใน `<input>`) | 🔴 |
| C5 | mime type ตรวจจาก content ไม่ใช่แค่ชื่อไฟล์ | เปลี่ยนนามสกุล `.exe` → `.jpg` แล้วอัป ต้องถูกปฏิเสธ | 🟠 |
| C6 | soft delete จริง | ลบ entry → แถวยังอยู่ `deleted_at` ไม่ null และ `select` ไม่เห็น | 🟠 |
| C7 | counter ถูกต้อง | เพิ่ม 3 ลบ 1 → `entry_count = 2` | 🟠 |
| C7b | **counter ถูกต้องตอนย้าย entry ข้ามเรื่อง** | ย้าย entry → เรื่องต้นทางต้องลด ไม่ใช่ค้างตัวเลขเก่า (เทส T17) | 🟠 |
| C10 | `link_previews` เขียนผ่าน admin client เท่านั้น | `grep -rn "link_previews" features/ app/` → ทุกจุดที่เขียนต้องมาจาก `lib/supabase/admin.ts` | 🔴 |
| C11 | slug/ค่าที่มี CHECK constraint สร้างได้จริง | `share_slug` ต้องเป็น `[a-z0-9]{12,24}` — nanoid ต้องใช้ custom alphabet | 🟠 |
| C8 | ค้นหาไทยได้ | ค้น "คาเฟ่", "เชียงใหม่" เจอ | 🟠 |
| C9 | signed URL หมดอายุจริง | อายุ ≤ 10 นาที และ URL ไม่ถูก cache ลง HTML แบบถาวร | 🟠 |

---

## D. เฟส P2 — Capture (เฟสที่เสี่ยงที่สุด)

| # | ตรวจ | เกณฑ์ผ่าน | ระดับ |
|---|---|---|---|
| D1 | **SSRF: private IP** | ยิง `http://127.0.0.1`, `http://10.0.0.1`, `http://192.168.1.1`, `http://[::1]` → ถูกบล็อกทุกอัน | 🔴 |
| D2 | **SSRF: cloud metadata** | `http://169.254.169.254/latest/meta-data/` → ถูกบล็อก | 🔴 |
| D3 | **SSRF: redirect** | URL สาธารณะที่ 302 ไป `127.0.0.1` → **ต้องถูกบล็อกที่ชั้น redirect** (นี่คือจุดที่คนพลาดบ่อยที่สุด) | 🔴 |
| D4 | **SSRF: DNS rebinding** | โดเมนที่ resolve เป็น private IP → ถูกบล็อก (ต้องเช็ค IP หลัง resolve ไม่ใช่เช็คแค่ชื่อโดเมน) | 🔴 |
| D5 | SSRF: protocol | `file://`, `gopher://`, `data:` → ถูกบล็อก | 🔴 |
| D6 | timeout + ขนาด body | เซิร์ฟเวอร์ที่ตอบช้า 30 วิ / ส่ง body 100MB → ตัดที่ 5 วิ / 512KB | 🟠 |
| D7 | rate limit ทำงาน | ยิง 40 ครั้งใน 1 นาที → ถูกปฏิเสธหลังครั้งที่ 30 | 🟠 |
| D8 | **ดึง URL จาก `text` ได้** | payload แบบที่ TikTok ส่งจริง (URL ฝังอยู่ในข้อความ ไม่มี field `url`) ต้องดึงออกมาได้ | 🔴 |
| D9 | normalize URL ตัด tracking | `?_t=x&_r=1&utm_source=y` ตัดออกก่อน hash → ลิงก์เดียวกันต้องได้ hash เดียวกัน | 🟠 |
| D10 | preview พังแล้วยังเซฟได้ | จำลอง provider ล่ม → เซฟลิงก์ดิบสำเร็จ + status `failed` + ปุ่มลองใหม่ | 🟠 |
| D11 | ยังไม่ login ตอนแชร์ | share → login → กลับมาที่ `/share` โดย params ไม่หาย | 🟠 |
| D12 | ครบ 2 แตะจริง | E2E บน mobile viewport นับจำนวนการแตะจากหน้า `/share` ถึงเซฟเสร็จ = 1 | 🟠 |

---

## E. เฟส P3 — Travel Kit

| # | ตรวจ | เกณฑ์ผ่าน | ระดับ |
|---|---|---|---|
| E1 | detector เป็น pure function | ไม่มี `fetch`/`await`/อ่าน DB ในไฟล์ `detect-travel-intent.ts` | 🟠 |
| E2 | ทักถูก | "ทริปเชียงใหม่" ทัก · "คาเฟ่ใกล้บ้าน" ไม่ทัก · "ที่พักหัวหิน" ทัก | 🟠 |
| E3 | **ไม่เปิดโหมดเองอัตโนมัติ** | ไม่ว่าคะแนนเท่าไหร่ `is_travel_enabled` ต้องยังเป็น `false` จนกว่าผู้ใช้จะกด | 🔴 |
| E4 | จำการปฏิเสธ | กด "ไม่ต้อง" แล้วรีเฟรช → ไม่ทักซ้ำ | 🟠 |
| E5 | บอกเหตุผลที่ทัก | แบนเนอร์แสดง `matchedTerms` จริง ไม่ใช่ข้อความตายตัว | 🟡 |
| E6 | เปิดซ้ำ idempotent | กดเปิดโหมด 2 ครั้ง → ไม่เกิดแถว `trips` หรือ `trip_days` ซ้ำ | 🟠 |
| E7 | **ปิดโหมด = ซ่อน ไม่ลบ** | ปิดแล้วเปิดใหม่ → itinerary/checklist/งบ ครบเหมือนเดิม | 🔴 |
| E8 | ลบ entry ต้นทางแล้ว stop ยังอยู่ | `entry_id` เป็น null ไม่ใช่ stop หายไป | 🟠 |
| E9 | **core ไม่ import kit** | `grep -rn "features/travel" app/ features/topics features/entries features/capture` เจอได้เฉพาะไฟล์ route ของหน้า plan | 🟠 |
| E10 | คำนวณงบถูก | `sum(budget_items) + sum(trip_stops.est_cost)` เทียบ `budget_total` — เทสด้วยทศนิยม | 🟠 |
| E11 | ลากได้ด้วยคีย์บอร์ด | dnd-kit ตั้ง keyboard sensor แล้ว (a11y) | 🟡 |

---

## F. เฟส P4 — Share

| # | ตรวจ | เกณฑ์ผ่าน | ระดับ |
|---|---|---|---|
| F1 | **service role ไม่รั่วไปหน้า public** | ดู HTML/JS ที่ส่งไป client ของ `/s/[slug]` → ต้องไม่มี key | 🔴 |
| F2 | slug เดาไม่ได้ | ยาว ≥ 12 ตัว สุ่มด้วย CSPRNG ไม่ใช่ `Math.random()` | 🟠 |
| F3 | ปิดแชร์แล้ว 404 ทันที | ไม่มี cache ค้างให้เข้าถึงได้ต่อ | 🔴 |
| F4 | 404 ไม่รั่วข้อมูล | slug ที่ปิดไปแล้วกับ slug มั่ว ต้องได้หน้าเดียวกัน ไม่บอกว่า "เคยมี" | 🟠 |
| F5 | `noindex` | หน้า `/s/[slug]` มี `robots: noindex` | 🟠 |
| F6 | ไฟล์ในหน้า public ผ่าน signed URL ที่เช็ค `is_public` ก่อน | อ่านโค้ดยืนยันลำดับ: เช็คสิทธิ์ → แล้วค่อยออก URL | 🔴 |

---

## รูปแบบรายงานผล audit

```
## Audit: P<n> — <ผ่าน / ผ่านแบบมีข้อสังเกต / ไม่ผ่าน>

### 🔴 CRITICAL (บล็อก)
1. <สรุปปัญหา 1 ประโยค>
   - ไฟล์: path:line
   - เกิดขึ้นเมื่อ: <อินพุต/สถานะ> → <ผลที่ผิด>
   - หลักฐาน: <เอาต์พุตคำสั่งจริง>
   - แก้ยังไง: <ทางแก้ที่เจาะจง>

### 🟠 HIGH
...

### ✅ ผ่านแล้ว
- <ข้อที่ตรวจแล้วผ่าน พร้อมหลักฐานสั้นๆ>
```

**กติกาของผู้ตรวจ:**
- ทุก finding ต้องมี **หลักฐานที่รันได้จริง** ห้ามรายงานจากการเดาว่าโค้ด "น่าจะ" ผิด
- ถ้าตรวจข้อไหนไม่ได้ ให้เขียนว่า "ตรวจไม่ได้ เพราะ..." อย่าเขียนว่าผ่าน
- แยกให้ชัดระหว่าง "ผิดสเปก" กับ "ไม่ถูกใจผู้ตรวจ" — อย่างหลังไปอยู่ ⚪ LOW
