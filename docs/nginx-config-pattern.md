# Runtime Config and constant (nginx + config.json)

## ปัญหาที่แก้ มีไว้สำหรับพวกที่ต้องการ Self Host

พวก Backend path ที่อาจเปลี่ยนแปลงได้ตลอดเวลา และทีม ไม่ต้องการมานั่งแก้ใหม่ในโค้ดเก่าเพื่อเริ่มการดันขึ้นเว็บ deployment อะไรต่างๆ ใหม่ทั้งหมด
- React build ครั้งเดียว แต่ต้องการ deploy หลาย environment ที่มี backend URL ต่างกัน
```env
dev     → http://localhost:3001
staging → http://10.2.113.26/api/v2
prod    → https://api.myapp.com/v2
# โดยปกติจะ Store แค่ใน .env อย่างเดียวถ้าไม่กังวลการเปลี่ยนแปลงภายหลัง
```

ถ้า hardcode URL ใน code → ต้อง rebuild ทุกครั้ง  
ถ้าใช้ `.env` → bake เข้า bundle ตอน build → ต้อง rebuild ทุกครั้งเช่นกัน

**วิธีแก้:** fetch URL มาตอน runtime จาก `config.json` ที่ nginx serve แยกต่างหาก

## ข้อยกเว้น
หากใช้บริการ hosting เช่่น , Netlify, Render, Vercel พวกนี้สามารถ Deploy ใหม่ได้อย่างรวดเร็ว แล้วก็สามารถแก้  .env file ได้โดยตรง

---

## Architecture

```
Browser
  │
  ├─ GET /app/index.html          → nginx → /var/www/app/index.html
  ├─ GET /app/static/js/main.js   → nginx → /var/www/app/static/js/main.js
  ├─ GET /config/config.json      → nginx → /var/www/config/config.json  ← แก้ได้ไม่ต้อง rebuild
  └─ GET /api/...                 → nginx → proxy → Express :3001
```

---

## config.json

```json
{
  "REACT_APP_API_ENDPOINT": "http://10.2.113.26/api/v2",
  "REACT_APP_API_ENDPOINT_AUTHEN": "/api/auth",
  "REACT_APP_API_ENDPOINT_USER": "/api/user",
  "REACT_APP_API_ENDPOINT_LOG": "/api/log"
}
```
ไฟล์นี้ **ไม่ได้เป็นส่วนของ React build** — เป็นแค่ JSON ธรรมดาที่ nginx serve  
แก้ไขได้โดยตรงบน server แล้ว reload browser — ไม่ต้อง build ใหม่เลย

---

## nginx config

```nginx
server {
    listen 80;
    server_name _;

    # React app (build output)
    location /app/ {
        alias /var/www/app/;
        try_files $uri /app/index.html;  # SPA fallback
    }

    # config.json — serve แยก แก้ได้อิสระ
    location /config/ {
        alias /var/www/config/;
        add_header Cache-Control "no-cache";  # ไม่ cache เพื่อให้ได้ค่าใหม่เสมอ
    }

    # Reverse proxy ไป backend
    location /api/ {
        proxy_pass         http://localhost:3001/;
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
    }
}
```

---

## การใช้งานใน React

**boot.js** — โหลด config ก่อน render app

```js
let _config = {};

export async function loadConfig() {
  const res = await fetch("/config/config.json");
  if (!res.ok) throw new Error("Cannot load config");
  _config = await res.json();
}

export const getEnv = (key) => _config[key] ?? "";
```

**main.jsx** — รอ config โหลดก่อน mount

```jsx
import { loadConfig } from "./boot";

loadConfig().then(() => {
  ReactDOM.createRoot(document.getElementById("root")).render(<App />);
});
```

**api.js** — ใช้ getEnv แทน hardcode

```js
import { getEnv } from "./boot";

export async function request(method, path, body) {
  const base = getEnv("REACT_APP_API_ENDPOINT");
  const res = await fetch(`${base}${path}`, {
    method,
    headers: { "Content-Type": "application/json" },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  if (!res.ok) throw new Error(await res.text());
  return res.json();
}
```

---

## เทียบ 3 วิธี

| วิธี | เปลี่ยน URL | Rebuild? | เหมาะกับ |
|---|---|---|---|
| Hardcode ใน code | แก้ code | ✅ ต้อง | dev เล็กๆ |
| `.env` (Vite) | แก้ .env | ✅ ต้อง | team เดียว, env ไม่ซับซ้อน |
| `config.json` runtime | แก้ไฟล์บน server | ❌ ไม่ต้อง | หลาย env, deploy artifact เดียว |

---

## ใน project นี้

ตอนนี้ใช้ hardcode ใน [constants.js](../frontend/src/utils/constants.js):

```js
export const API = "http://localhost:3001";
```

เพียงพอสำหรับ dev — ถ้าอยาก migrate ไป config.json pattern ในอนาคตดู [github-actions-deploy.md](./github-actions-deploy.md)
