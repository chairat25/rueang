# AGENTS.md — กติกาสำหรับ AI agent ที่เขียนโค้ดในโปรเจกต์นี้

> อ่านไฟล์นี้ให้จบก่อนแตะโค้ดบรรทัดแรก
> **Source of truth ของงานคือ `implementplan.md`** — ไฟล์นี้คือกติกา ส่วนแผนคือเนื้องาน

---

## 0. บริบท 30 วินาที

**Rueang (เรื่อง)** = แอปเก็บ "เรื่อง" 1 เรื่อง = หลาย entry (ข้อความ / ลิงก์ / ไฟล์ / ผสมกัน)
แก้ปัญหา: เห็นที่เที่ยวใน TikTok กดหัวใจไว้ พอจะไปจริงลืมว่าจะไปไหน
ถ้าเรื่องไหนดูเหมือนทริป ระบบจะ **ทัก** ให้เปิดโหมดวางแผนเที่ยว (ผู้ใช้กดเอง ไม่เปิดอัตโนมัติ)

ผู้ใช้เป็นคนไทย **UI ทั้งหมดเป็นภาษาไทย** รวมถึงข้อความ error และ empty state

---

## 1. กระบวนการทำงาน (บังคับ)

1. หยิบงานทีละ task ตามลำดับใน `implementplan.md` §10 — **ห้ามข้ามเฟส**
2. **TDD เสมอ**: เขียนเทสให้แดงก่อน → เขียนโค้ดให้เขียว → refactor
3. จบ task → รัน `yarn verify` (lint + typecheck + test) ต้องเขียว
4. จบเฟส → เช็ค DoD ของเฟสนั้นให้ครบทุกข้อ แล้วหยุด **รอ audit ก่อนขึ้นเฟสถัดไป**
5. commit เป็นก้อนเล็กตาม conventional commits: `feat:` `fix:` `refactor:` `test:` `chore:`

> โค้ดในโปรเจกต์นี้จะถูก **audit ความถูกต้องโดย agent อีกตัว** ตาม `docs/audit-checklist.md`
> อ่าน checklist นั้นไว้ด้วย จะได้รู้ว่าอะไรจะถูกตรวจ

---

## 2. ข้อห้ามเด็ดขาด (ละเมิด = ตกทันที)

| # | ห้าม | เพราะ |
|---|---|---|
| H1 | ห้ามแก้ไฟล์ใน `supabase/migrations/000[123]_*.sql` | schema + RLS ถูก freeze ไว้แล้ว ถ้าเห็นว่าผิดจริงให้ **หยุดแล้วรายงาน** อย่าแก้เอง — ถ้าต้องเพิ่มให้สร้าง `0004_*.sql` ใหม่ |
| H2 | ห้าม import `SUPABASE_SERVICE_ROLE_KEY` นอก `lib/supabase/admin.ts` | key นี้ bypass RLS ทั้งหมด หลุดไป client = ข้อมูลทุกคนหลุด |
| H3 | ห้ามสร้าง RLS policy ให้ role `anon` | จะไล่ query หา public topic ของคนอื่นได้ผ่าน PostgREST |
| H4 | ห้ามตั้ง storage bucket เป็น public | ไฟล์ผู้ใช้ต้องเข้าถึงผ่าน signed URL เท่านั้น |
| H5 | ห้าม `fetch()` URL จากผู้ใช้โดยไม่ผ่าน `lib/url/ssrf-guard.ts` | SSRF — ดู `implementplan.md` §5.4 ต้องครบทั้ง 6 ข้อ |
| H6 | ห้ามกลืน error เงียบๆ (`catch {}` เปล่า, `catch { return null }` โดยไม่ log) | ทุก catch ต้อง log ฝั่ง server + คืนข้อความไทยที่ผู้ใช้เข้าใจ |
| H7 | ห้าม hardcode ค่า config / คีย์ / ลิมิต ในโค้ด | ใช้ `lib/env.ts` หรือ constant ที่ตั้งชื่อแล้ว |
| H8 | ห้าม mutate object/array เดิม | ใช้ spread / `toSorted` / `map` คืนของใหม่เสมอ |
| H9 | ห้ามให้ `features/travel/` ถูก import จาก core (`features/topics`, `features/entries`, `features/capture`) | kit อ้าง core ได้ core ห้ามอ้าง kit |
| H10 | ห้าม `--force`, `git push -f`, ลบไฟล์ที่ไม่ได้สร้างเอง, หรือแก้ `implementplan.md` | แผนเปลี่ยนได้โดยเจ้าของโปรเจกต์เท่านั้น |

---

## 3. มาตรฐานโค้ด

**ขนาด**
- ไฟล์ ≤ 800 บรรทัด (ปกติควรอยู่ 200–400) — เกินแล้วให้แตกไฟล์
- ฟังก์ชัน ≤ 50 บรรทัด
- ซ้อน if ไม่เกิน 4 ชั้น → ใช้ early return

**ตั้งชื่อ**
- ตัวแปร/ฟังก์ชัน `camelCase` · type/component `PascalCase` · ค่าคงที่ `UPPER_SNAKE_CASE` · hook ขึ้นต้น `use`
- boolean ขึ้นต้นด้วย `is` / `has` / `should` / `can`

**TypeScript**
- `strict: true`, **ห้ามใช้ `any`** (ถ้าจำเป็นจริงใช้ `unknown` แล้ว narrow)
- ข้อมูลจากภายนอกทุกชิ้น (form, searchParams, API response, share params) ต้องผ่าน `zod.parse()` ก่อนใช้
- `readonly` กับ props/type ที่ไม่ควรถูกแก้

**การจัดไฟล์** — แบ่งตาม feature ไม่ใช่ตามชนิดไฟล์ ดูโครงสร้างใน `implementplan.md` §9
แต่ละ feature มี `components/` `actions.ts` `queries.ts` `schema.ts`

**Server Action ทุกตัวต้องมีโครงนี้**
```ts
export async function doSomething(input: unknown) {
  const parsed = doSomethingSchema.parse(input);      // 1. validate ที่ boundary
  const supabase = await createServerClient();         // 2. client ที่ผูก session ผู้ใช้
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { ok: false, error: 'กรุณาเข้าสู่ระบบ' } as const;   // 3. เช็ค auth

  const { data, error } = await supabase.from('...')...;                // 4. ให้ RLS ทำงาน
  if (error) {
    console.error('[doSomething]', error);                              // 5. log จริงฝั่ง server
    return { ok: false, error: 'บันทึกไม่สำเร็จ ลองใหม่อีกครั้ง' } as const;
  }
  return { ok: true, data } as const;                                   // 6. envelope เดียวกันเสมอ
}
```

**รูปแบบผลลัพธ์มาตรฐาน:** `{ ok: true, data }` หรือ `{ ok: false, error: string }` — ห้าม throw ข้าม boundary ไปหา client

---

## 4. เทส

- เป้า **coverage ≥ 80%** — เช็คด้วย `yarn test:coverage`
- โครงสร้าง Arrange-Act-Assert
- ชื่อเทสบอก **พฤติกรรม** ไม่ใช่ชื่อฟังก์ชัน: `test('ไม่ทักเมื่อเจอแค่คำแวดล้อมคำเดียว')`
- เทสที่ห้ามขาด ดู `implementplan.md` §11 — ลอกชื่อเทสไปใช้ได้เลย
- **RLS ต้องมี integration test จริง** (สร้าง user A/B แล้วยิงข้าม) ไม่ใช่แค่ mock

---

## 5. คำสั่งที่ต้องมีใน `package.json`

```json
{
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "lint": "next lint",
    "typecheck": "tsc --noEmit",
    "test": "vitest run",
    "test:coverage": "vitest run --coverage",
    "test:e2e": "playwright test",
    "verify": "yarn lint && yarn typecheck && yarn test",
    "db:reset": "supabase db reset",
    "db:push": "supabase db push"
  }
}
```

---

## 6. เมื่อไม่แน่ใจ

- แผนขัดกันเอง / schema ดูผิด / ต้องตัดสินใจนอกแผน → **หยุด เขียนคำถามไว้ อย่าเดาแล้วเขียนต่อ**
- ห้ามขยายขอบเขตเอง — ของที่อยู่ใน "นอกขอบเขต" (`implementplan.md` §1.4) ห้ามทำแม้จะง่าย
- Next.js 16 มี breaking changes จาก 15 (async `params`/`searchParams`, caching defaults)
  **ก่อนเขียน route/page ให้อ่าน `node_modules/next/dist/docs/` ก่อน** อย่าเขียนจากความจำ
