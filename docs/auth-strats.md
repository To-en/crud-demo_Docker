# JWT Authentication Strategy

## Architecture Overview

```
Client → [soc-server / soc-log-service]
              ↓ (verify local)         ↓ (delegate)
         jwt.verify()       soc-authentication-service
                                  POST /authentication
```

---

## How Each Layer Handles Auth

### soc-authentication-service — Issuer + Validator (source of truth)

- `JwtStrategy` (passport-jwt) — extracts Bearer token, verifies with `AUTHENTICATION_SECRETKEY`
- `ignoreExpiration: true` → manual expiry check inside `validate()`
- Exposes `POST /authentication` → accepts `{ authorization: token }` → returns user data
- `JwtAuthGuard` used via `@UseGuards(JwtAuthGuard)` on NestJS controllers

Key files:
- `soc-authentication-service/src/jwt-token/jwt.strategy.ts`
- `soc-authentication-service/src/jwt-token/constants.ts`

### soc-server — Verify Locally (Express)

- Middleware at `src/middlewares/auth.middleware.js`
- Calls `Jwt.verify(token, process.env.JWT_SECRET)` directly
- Looks up user with `User.findByPk(jwt.ID)` → sets `req.user` (no password)
- Applied per-route, not globally (e.g. `playback.routes.js`)

### soc-log-service — Delegate to Auth Service (NestJS)

- `AuthMiddleware` → calls `AuthenService.checkJWTToken()`
- Does **not** verify JWT locally — POSTs token to `AUTHENTICATION_API/authentication`
- Sets `req.user` from response data
- Also has `checkTokenBackEnd()` for service-to-service static token checks (`TOKEN_BACKEND`, `TOKEN_TSK`, `TOKEN_PEA` env vars)

Key files:
- `soc-log-service/src/middleware/auth.middleware.ts`
- `soc-log-service/src/authen/authen.service.ts`

---

## Building from Scratch — Step by Step

### Step 1: Issue Tokens (login endpoint)

```js
const payload = { ID: user.id, role: user.role }
const accessToken  = jwt.sign(payload, process.env.JWT_SECRET,         { expiresIn: '15m' })
const refreshToken = jwt.sign(payload, process.env.JWT_REFRESH_SECRET, { expiresIn: '7d' })
res.json({ accessToken, refreshToken })
```

Required env:
```
JWT_SECRET=<random 256-bit string>
JWT_REFRESH_SECRET=<different random 256-bit string>
```

### Step 2: Verify Middleware

**Express:**
```js
module.exports = async (req, res, next) => {
  const auth = req.headers['authorization']
  if (!auth?.startsWith('Bearer '))
    return res.status(401).json({ error: 'Missing token' })

  try {
    req.user = jwt.verify(auth.split(' ')[1], process.env.JWT_SECRET)
    next()
  } catch (err) {
    return res.status(403).json({ error: 'Invalid token' })
  }
}
```

**NestJS (delegate pattern):**
```ts
const resp = await this.http
  .post(process.env.AUTH_API + '/authentication', { authorization: token })
  .toPromise()
if (resp.data.status !== 200) throw resp.data
req.user = resp.data.data
next()
```

### Step 3: Apply Middleware

**Express — global with exclusions:**
```js
app.use((req, res, next) => {
  if (req.path === '/login') return next()
  authMiddleware(req, res, next)
})
```

**NestJS — AppModule:**
```ts
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer
      .apply(AuthMiddleware)
      .exclude({ path: 'login', method: RequestMethod.POST })
      .forRoutes('*')
  }
}
```

### Step 4: Refresh Token Flow

```
access token expires (403)
  → client sends refreshToken to POST /refresh
  → server verifies with JWT_REFRESH_SECRET
  → issues new accessToken
  → if refresh also expired → force re-login
```

---

## Local Verify vs Delegate

| | Local Verify | Delegate to Auth-Service |
|---|---|---|
| Speed | Fast — no network | Slower — HTTP hop |
| Secret distribution | Every service needs it | Only auth-service knows it |
| Instant token revocation | No (needs blacklist) | Yes — auth-service controls it |
| Best for | Few services, simple setup | Microservice architecture |

**Recommendation for this project:** Use delegate pattern (soc-log-service style) — `soc-authentication-service` already exists, no need to distribute the secret.

---

## Security Checklist

- [ ] `JWT_SECRET` must not use fallback hardcoded value — see `constants.ts` line 2
- [ ] `ignoreExpiration: true` in JwtStrategy — confirm `validate()` checks expiry manually
- [ ] Store refresh tokens server-side (DB or Redis) to enable revocation
- [ ] HTTPS only — tokens in headers are trivially intercepted over HTTP



### Protected / Public ROutes side

`Frontend`
/ → /market          (public, no token needed)

/cart (submit order) → ต้องมี token → ถ้าไม่มี redirect /login
/order-history       → ต้องมี token → ถ้าไม่มี redirect /login
/ingredients (CRUD)  → ต้องมี token (admin only)


`Backend`
GET  /api/ingredients        → public (แค่ดู)
POST /api/ingredients        → protected + admin (เพิ่มสินค้า)
PUT  /api/ingredients/:id    → protected + admin (แก้ไข)
DELETE /api/ingredients/:id  → protected + admin (ลบ)

POST /api/orders             → protected (ต้อง login ถึง order ได้)
GET  /api/order-history      → protected
