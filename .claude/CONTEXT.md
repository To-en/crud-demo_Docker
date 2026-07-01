# Ingredient Ordering — CRUD Demo

## Doc Writing Preferences

When writing project documentation (CONTEXT.md, memory files, API docs):
- Prefer explicit format over ambiguous shorthand
- Do not collapse tables or lists to save space — full rows, full columns
- These preferences apply to docs only, not to Claude's conversational responses

---

Fullstack webapp where domain is the demo. High school students browse available ingredients (app acts as a market), add to cart, and submit a lunch order. Admin manages stock. REST and GraphQL are demonstrated using real domain entities, not dummy data — same DB, different mental model.

---

## Domain

**What**: Students browse available ingredients, build a cart, and submit a lunch order. Admin creates/updates/deletes ingredient listings and views all orders.

**Users** (role in DB):
- **Student** (role 0) — browses ingredients, submits orders. Username format: `M6/2-group1` (regex `^[A-Z]\d\/\d-group\d+$`). `class` set from `classroom` field at registration.
- **Teacher** (role 1) — confirms/cancels orders, sees only their class's history. Username: `*@crud-personel.ac.th`.
- **Admin** (role 2) — manages ingredient stock, sees all orders. Username: `admin` or `*@crud-admin.ac.th`.

Role assigned automatically at registration via `assignRole(username)` in `user.service.js` — derived from username format, not a manual field.

**Peak load**: Spikes once a week when nearly all ~5,000 students access simultaneously. Backend must handle this burst (queue, cache, rate-limit).

**Core student flow**:
1. Browse available ingredient list (filtered by stock, category)
2. Add ingredients to cart
3. Submit order → status starts `pending`

**Order lifecycle**: `pending → confirmed → cancelled`

---

## Language

JavaScript (ESM) — Node.js backend, React frontend.

---

## Data Model

**Ingredient** (managed by admin via REST):
```
{ id, name, unit: "kg"|"g"|"L"|"ml"|"pcs", price: number, stock: number, category: "Grain"|"Protein"|"Vegetable"|"Dairy"|"Spice", imageUrl: string }
```
`imageUrl` — admin uploads via Supabase (`image.middleware.js`); stored as URL. Frontend reads from JSON response directly.
`nutrition_facts` — separate table linked to ingredient; not surfaced in UI yet (future).
Seed: 8 everyday cooking ingredients in `backend/src/models/ingredients.js`. Target ~20 for full demo.

**Order**:
```
{ id, name, userId, ingreId: int[], qty: int[], grandTotal: int, status: 0|1|2, createdDate, lastModified, deleteAt }
```
`status`: `0=pending`, `1=confirmed`, `2=cancelled`. Stored as `SMALLINT`.
`deleteAt`: soft-delete timestamp — set on delete, not a hard row removal.
Table: `crud_market.orders`. No separate `order_items` table — items stored as parallel arrays.

**User** (all roles share one table `crud_market.users`):
```
{ id, username, password, class, role: 0|1|2, refreshToken, budget, createdDate, lastModified, deleteAt }
```
`deleteAt`: soft-delete. `class`: classroom string e.g. `"M6/2"` — used for teacher scoping.

---

## API Experiment Plan

**Strategy**: REST-first. Build the full domain in REST, feel the friction, then add GQL alongside it for comparison. gRPC dropped — proto codegen + transport overhead is out of scope for this demo.

### Phase 1 — REST (current)
Full CRUD for `ingredients` and `orders` over HTTP. Backend complete.

**Planned additions before Phase 2**:
- JWT cookies (replacing Bearer token in header) — see `docs/improve-jwt-with🍪.md`
- Redis token blacklist for true logout — see `docs/token-blacklist-plan.md`

### Phase 2 — GQL (alongside REST, same DB)
Add `/graphql` endpoint. Implement student-facing read side only — ingredient filtering and order status queries. These are where REST's over-fetching / multiple round-trip pain shows up most clearly. Order *submission* stays REST (simple POST, GQL mutation adds no insight).

| Protocol | Scope | Why here |
|---|---|---|
| REST | Full CRUD — `ingredients` + `orders` (admin + student writes) | Baseline; teaches HTTP verbs + resource design |
| GQL | Read side — ingredient queries + order status (student) | Contrast: same data, schema-first vs resource-first |

**Resource vs Schema**: REST organises around resource nouns (`/ingredients`, `/orders`). GQL organises around a typed schema (graph of entities). Same DB, different mental model — core comparison of the experiment.

---

## Services

**REST API** (`backend/`, Express ESM, port `3001`):
Auto-loads `*.routes.js` from `src/routes/` flat under `/api`. CORS enabled. Baseline for comparing API styles.

**GraphQL API** (Phase 2, port `4000`):
Single `/graphql` endpoint. Ingredient queries + order status queries only — read side. Added alongside REST on same DB so the two can be compared directly.

**Frontend** (`frontend/`, React 18 + Vite, port `5173`):

| Page | Status | Notes |
|---|---|---|
| Login / Register | 50% | `api.js` + 2 auth contexts done; page/UI elements not yet built |
| Ingredient Market + Cart | Built | Single page — browse ingredients, manage cart, submit order via button |
| Order History | Built | Student/teacher view of past orders (page 2) |
| Admin Panel | Future | Ingredient CRUD for admin role |

Integrates REST first; will be compared with GQL in Phase 2.

**PostgreSQL** (`crud_market` schema):
Tables: `ingredients`, `orders`, `users`, `school`, `nutrition_facts`. Shared across REST and GQL. Must handle ~5,000 concurrent reads on peak day.

---

## Key Files

### Entry Points
| File | Role |
|---|---|
| `backend/src/main.js` | Express bootstrap — mounts `/api` router, health check at `/health` |
| `backend/src/config.js` | Loads `.env` via dotenv + dotenv-expand |
| `backend/src/sequelize.js` | Sequelize instance — reads `DATABASE_URL` from config |
| `backend/src/swagger.js` | Swagger-jsdoc setup — scans routes for `@swagger` annotations |
| `backend/src/logger.js` | Winston logger |

### Routes
| File | Role |
|---|---|
| `backend/src/routes/index.js` | Auth routes + auth wall (`validate`); auto-loads all `*.routes.js` flat under `/api` |
| `backend/src/routes/ingredient.routes.js` | Ingredient market routes — mounted at `/api/ingredient` |
| `backend/src/routes/order.routes.js` | Order submit + status routes — mounted at `/api/order` |
| `backend/src/routes/order-history.routes.js` | Order history routes — mounted at `/api/order` |

### Controllers
| File | Role |
|---|---|
| `backend/src/controllers/user.controller.js` | Login, register, token refresh, distribute-budget |
| `backend/src/controllers/ingredient.controller.js` | CRUD handlers for ingredient listings (admin) |
| `backend/src/controllers/order.controller.js` | Submit order + confirm/cancel (deducts budget on confirm) |
| `backend/src/controllers/order-history.controller.js` | List, search, edit, bill detail, export, delete |

### Services
| File | Role |
|---|---|
| `backend/src/services/user.service.js` | JWT + bcrypt user operations |
| `backend/src/services/ingredient.service.js` | Ingredient DB queries + image URL handling |
| `backend/src/services/order-history.service.js` | Order history DB operations + CSV export |
| `backend/src/services/budget.service.js` | Computes `grandTotal` from `ingreId[]` + `qty[]`; called at order creation |
| `backend/src/services/payment.service.js` | Admin-side budget distribution logic |

### Models
| File | Role |
|---|---|
| `backend/src/models/index.js` | Sequelize model registry |
| `backend/src/models/ingredients.model.js` | Ingredient model → `crud_market.ingredients` |
| `backend/src/models/orders.model.js` | Order model — parallel arrays `ingreId[]` + `qty[]` |
| `backend/src/models/users.model.js` | User model — student/teacher/admin, holds `budget` |
| `backend/src/models/school.model.js` | School model — central budget pool |
| `backend/src/models/nutritions.model.js` | Nutrition facts model → `nutrition_facts` |

### Middleware
| File | Role |
|---|---|
| `backend/src/middleware/auth.middleware.js` | JWT validation — sets `req.user`; `requireRole` guard |
| `backend/src/middleware/image.middleware.js` | Supabase image upload for ingredient images |

### DB
| File | Role |
|---|---|
| `backend/db/create.psql` | DDL — `crud_market` schema + all tables |
| `backend/db/mock.psql` | Seed — school budget, users, Thai ingredients, orders |

### Frontend & GQL
| File | Role |
|---|---|
| `frontend/src/App.jsx` | Ingredient browse → cart → order form → confirmation; live API log panel |
| `backend/src/gql/CRUD.gql` | GQL schema stub (empty — Phase 2) |

---

## API Endpoint Groups

### Auth (no auth required)

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/api/login` | Login — returns usernam + JWT access + refresh tokens |
| POST | `/api/listClass` | List available class drop down |
| POST | `/api/register` | Register new user |
| POST | `/api/refresh` | Refresh access token |

### Budget

| Method | Path | Access | Purpose |
|--------|------|--------|---------|
| POST | `/api/distribute-budget` | Admin (role 2) | Distribute central budget to all classrooms |

### Ingredient Market
Students: read-only (public, no auth required). Admin (role 2): CUD only. Deletes are permanent.
⚠️ **Known bug**: ingredient GET routes currently behind `validate` wall in `routes/index.js` — must be moved above it.

| Method | Path | Access | Purpose |
|--------|------|--------|---------|
| GET | `/api/ingredient` | Public | List all ingredients (paginated; filter by `?category=`, `?inStock=`) |
| GET | `/api/ingredient/search` | Public | Search by name, category, stock status (`?q=`, `?category=`, `?inStock=`) |
| POST | `/api/ingredient/create` | Admin (role 2) | Create new ingredient listing |
| PUT | `/api/ingredient/:id` | Admin (role 2) | Update ingredient (name, unit, stock, category) |
| DELETE | `/api/ingredient/:id` | Admin (role 2) | Delete ingredient (permanent) |

### Orders
Body uses parallel arrays: `ingreId[]` + `qty[]`. Budget not deducted until confirmed.

| Method | Path | Access | Purpose |
|--------|------|--------|---------|
| POST | `/api/order/submit` | Student (role 0) | Submit order — status starts `pending`, no budget deducted |
| PATCH | `/api/order/:id/status` | Teacher/Admin (role 1, 2) | Set `confirmed` (deducts budget) or `cancelled` |

### Order History
Scope via `scopeQueryByClassroom(user)` in `order-history.service.js`:
- role 0 (student): `WHERE userId = user.id`
- role 1 (teacher): `JOIN users WHERE User.class = user.class`
- role 2 (admin): no filter — sees all orders

| Method | Path | Access | Purpose |
|--------|------|--------|---------|
| GET | `/api/order` | Authenticated | List past orders (paginated) |
| GET | `/api/order/search` | Authenticated | Search by name or order ID (`?value=`) |
| GET | `/api/order/:id` | Authenticated | Full bill detail with expanded line items |
| PATCH | `/api/order/:id/edit` | Authenticated | Edit order — 403 if already confirmed or cancelled |
| GET | `/api/order/:id/export` | Authenticated | Export bill as CSV (PDF not implemented) |
| DELETE | `/api/order/:id/delete` | Teacher/Admin (role 1, 2) | Delete order from history |

---

## Infrastructure

**Local dev (current)**:
```
# terminal 1
cd backend && npm run dev     # nodemon, :3001

# terminal 2
cd frontend && npm run dev    # Vite, :5173
```
Health check: `GET http://localhost:3001/health`

**Local dev (target)**: Docker Compose — Postgres `5432`, REST `3001`, GQL `4000`, Frontend `5173`. Single `docker-compose up`.

**Seed**: `backend/db/mock.psql` — school budget, users, Thai ingredients, orders.
