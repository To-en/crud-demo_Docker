## Session Cookie vs JWT — ต่างกันยังไง

ตอนนี้ใช้ **JWT in header** (stateless):

```
client เก็บ token ใน localStorage
ทุก request: Authorization: Bearer <token>
backend verify math เท่านั้น ไม่แตะ DB
```

**Session Cookie** (stateful):

```
login → server สร้าง sessionId → เก็บใน DB/Redis
ส่ง Set-Cookie: sessionId=xxx; HttpOnly; Secure
ทุก request browser แนบ cookie อัตโนมัติ
backend query DB ด้วย sessionId → ได้ user
```

---

## สองแบบเสริมกันได้ — แต่ไม่จำเป็น

| |JWT (ปัจจุบัน)|Session Cookie|
|---|---|---|
|เก็บที่|localStorage (JS accessible)|HttpOnly cookie (JS เข้าไม่ได้)|
|XSS risk|สูง — token ถูกขโมยได้|ต่ำ — HttpOnly ป้องกัน|
|CSRF risk|ไม่มี (header-based)|มี — ต้องเพิ่ม CSRF token|
|Revoke ได้ทันที|ไม่ได้ (ต้อง blacklist)|ได้ — ลบ session จาก DB|
|Scale|ดี — stateless|ยากกว่า — ต้องแชร์ session store|

---

## ถ้าอยากเพิ่ม HttpOnly Cookie ให้ JWT

ไม่ต้องเปลี่ยน logic — แค่เปลี่ยน **วิธีส่ง token**:

**Backend — แทน `res.json({ accessToken })`:**

```js
res.cookie('accessToken', accessToken, {
  httpOnly: true,   // JS อ่านไม่ได้
  secure: true,     // HTTPS only
  sameSite: 'strict',
  maxAge: 30 * 60 * 1000  // 30 min
})
res.json({ ok: true })
```

**Middleware — อ่านจาก cookie แทน header:**

```js
const token = req.cookies?.accessToken
           ?? req.headers.authorization?.split(' ')[1]
```

ต้องเพิ่ม `cookie-parser` package:

```js
import cookieParser from 'cookie-parser'
app.use(cookieParser())
```

---

**สำหรับ project นี้** — localStorage + JWT ใช้ได้เลย เพราะ demo บน HTTP และไม่มี sensitive financial data จริง ถ้าจะ production ค่อยเปลี่ยนเป็น HttpOnly cookie

อยากเพิ่มไหม หรือไปต่อ frontend ก่อน?