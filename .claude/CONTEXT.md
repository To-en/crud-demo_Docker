# Ingredient Ordering — CRUD Demo

## Writing & Formatting Preferences

- Prefer clear and explicit format over ambiguous shorthand — even if more verbose
- Do not compromise content length or established writing style for brevity
- Adapt to match this preference; do not default to collapsed or minified patterns

---

Fullstack webapp where domain is the demo. High school students browse available ingredients (app acts as a market), add to cart, and submit a lunch order. Admin manages stock. Each API protocol (REST → GQL → gRPC) is demonstrated using real domain entities, not dummy data.

---

## Domain

**What**: Students browse available ingredients, build a cart, and submit a lunch order. Admin creates/updates/deletes ingredient listings and views all orders.

**Users**:
- **Student** — browses ingredients, plans meal, submits order. UX must be clear, fast, zero-friction. Drop-off is immediate if slow or confusing.
- **Admin** — manages ingredient stock and views order history.

**Peak load**: Spikes once a week when nearly all ~5,000 students access simultaneously. Backend must handle this burst (queue, cache, rate-limit).
_Avoid_: "daily noon spike" (peak is weekly, not daily)

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
{ id, name, unit: "kg"|"g"|"L"|"ml"|"pcs", price: number, stock: number, category: "Grain"|"Protein"|"Vegetable"|"Dairy"|"Spice" }
```
Seed: 8 everyday cooking ingredients in `backend/src/models/ingredients.js`. Target ~20 for full demo.
_Avoid_: product, item

**Order**:
```
{ id, studentId, items: [{ ingredientId, qty }], placedAt, status: "pending"|"confirmed"|"cancelled" }
```
Tables (Postgres target): `orders`, `order_items`
_Avoid_: cart (cart is pre-submit UI state, not a persisted entity)

**Student**:
```
{ id, name, grade }
```

---

## API Experiment Plan

**Strategy**: REST-first. Build the full domain in REST, feel the friction, then add GQL alongside it for comparison. gRPC dropped — proto codegen + transport overhead is out of scope for this demo.

### Phase 1 — REST (current)
Full CRUD for `ingredients` and `orders` over HTTP. Swap in-memory store for Postgres. This is the baseline.

### Phase 2 — GQL (alongside REST, same DB)
Add `/graphql` endpoint. Implement student-facing read side only — ingredient filtering and order status queries. These are where REST's over-fetching / multiple round-trip pain shows up most clearly. Order *submission* stays REST (simple POST, GQL mutation adds no insight).

| Protocol | Scope | Why here |
|---|---|---|
| REST | Full CRUD — `ingredients` + `orders` (admin + student writes) | Baseline; teaches HTTP verbs + resource design |
| GQL | Read side — ingredient queries + order status (student) | Contrast: same data, schema-first vs resource-first |

**Resource vs Schema**: REST organises around resource nouns (`/ingredients`, `/orders`). GQL organises around a typed schema (graph of entities). Same DB, different mental model — core comparison of the experiment.
_Avoid_: "endpoint-driven vs query-driven" (too abstract without context)
_Avoid_: gRPC (out of scope)

---

## Services

**REST API** (`backend/`, Express ESM, port `3001`):
Auto-loads `*.routes.js` from `src/routes/`. CORS enabled. Baseline for comparing API styles. Endpoints: `/crud/ingredients`, `/orders` (planned).
_Avoid_: "RESTful microservice"

**GraphQL API** (Phase 2, port `4000`):
Single `/graphql` endpoint. Ingredient queries + order status queries only — read side. Added alongside REST on same DB so the two can be compared directly.
_Avoid_: "GraphQL gateway", "federation", full mutation parity with REST

**Frontend** (`frontend/`, React 18 + Vite, port `5173`):
Ingredient browse → cart → order form → confirmation. Integrates REST first, then swapped/compared with GQL. Live API log panel (teaching tool shows raw HTTP traffic).
_Avoid_: SPA

**PostgreSQL** (target DB):
Tables: `ingredients`, `orders`, `order_items`. Shared across REST and GQL. Must handle ~5,000 concurrent reads on peak day.
Current state: in-memory store (`backend/src/models/ingredients.js`). Resets on restart.
_Avoid_: "database cluster", "sharded DB"

---

## Key Files

| File | Role |
|---|---|
| `backend/src/main.js` | Express bootstrap — mounts `/api` router, health check at `/health` |
| `backend/src/routes/index.js` | Auto-loads `*.routes.js`, mounts each at `/api/<filename>` |
| `backend/src/models/index.js` | Sequelize model registry — exports `db.Ingre`, `db.Order`, `db.User`, `db.Admin` |
| `backend/src/models/ingredient.model.js` | Ingredient Sequelize model — maps to `crud_market.ingredients` |
| `backend/src/models/order.model.js` | Order Sequelize model — parallel arrays `ingreId[]` + `qty[]` |
| `backend/src/models/user.model.js` | User model — student and teacher/admin, holds `budget` field |
| `backend/src/models/school.model.js` | School model — central budget pool (`crud_market.school`) |
| `backend/src/controllers/ingredient.controller.js` | CRUD handlers for ingredient listings (admin) |
| `backend/src/controllers/order.controller.js` | Submit order + confirm/cancel order status (deducts budget on confirm) |
| `backend/src/controllers/order-history.controller.js` | Student-facing order history — list, search, edit, view bill, export |
| `backend/src/middleware/auth.middleware.js` | JWT validation middleware — sets `req.user`; `requireRole`, `requireClassOwnership` guards |
| `backend/src/sequelize.js` | Sequelize instance — reads `DATABASE_URL` from config |
| `backend/src/config.js` | Loads `.env` via dotenv + dotenv-expand |
| `backend/db/create.psql` | DDL — creates `crud_market` schema and all tables |
| `backend/db/mock.psql` | Seed data — school budget, users, ingredients (Thai), orders |
| `frontend/src/App.jsx` | Ingredient browse → cart → order form → confirmation; live API log panel |
| `backend/src/gql/CRUD.gql` | GQL schema stub (empty — Phase 2) |

---

## API Endpoint Groups

### Ingredient Market System
Managed by admin. Students browse read-only. Admin creates/updates/deletes stock.

| Method | Path | Access | Purpose |
|--------|------|--------|---------|
| GET | `/api/ingredient/ingredient` | Public | List all ingredients (filter by category, stock) |
| GET | `/api/ingredient/ingredient/search` | Public | Search ingredient by name or id |
| POST | `/api/ingredient/ingredient/create` | Admin (role 2) | Create new ingredient listing |
| PUT | `/api/ingredient/ingredient/:id` | Admin (role 2) | Update ingredient (price, stock, name) |
| DELETE | `/api/ingredient/ingredient/:id` | Admin (role 2) | Soft-delete ingredient |

### Ordering System
Student submits cart as order. Budget not deducted until teacher/admin confirms.

| Method | Path | Access | Purpose |
|--------|------|--------|---------|
| POST | `/api/order/` | Authenticated | Submit order — creates record with `status: 0 (pending)` |
| PATCH | `/api/order/:id/status` | Teacher / Admin | Confirm or cancel order — deducts student budget on confirm |

### Order History Keeping
Student views and manages their own past orders.

| Method | Path | Access | Purpose |
|--------|------|--------|---------|
| POST | `/api/order-history/order/history` | Authenticated | List own past orders (paginated) |
| GET | `/api/order-history/order/history/search` | Authenticated | Search own orders by name or id |
| PATCH | `/api/order-history/order/history/:id` | Authenticated (class owner) | Edit order — only when `status = 0` (pending) |
| GET | `/api/order-history/order/history/:id` | Authenticated | View full bill detail for one order |
| GET | `/api/order-history/order/history/:id/export` | Authenticated | Export bill as PDF or CSV |
| DELETE | `/api/order-history/order/history/:id` | Teacher / Admin + class owner | Delete order from history |

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

**Seed**: ~20 sample ingredients (name, price, unit, stock, category). Lives in `backend/src/models/ingredients.js` now; target `db/schema.sql` + seed script once Postgres added.
_Avoid_: "fixture", "factory" — say "seed data"
