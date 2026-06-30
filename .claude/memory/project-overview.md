---
name: project-context
description: CRUD experiment — ingredient ordering for secondary school students, REST + GraphQL comparison
metadata:
  type: project
---

Fullstack CRUD experiment where REST and GraphQL serve the same domain so API styles can be compared directly. High school students browse ingredients (app acts as a market), add to cart, submit a lunch order. Admin manages stock.

**Why:** Learn backend principles through direct comparison, not tutorials.
**How to apply:** Tie suggestions back to the REST vs GQL contrast.

---

## Domain

**Users**:
- **Student** — browses ingredients, builds cart, submits order. UX must be zero-friction; drop-off is immediate if slow.
- **Admin** — manages ingredient stock, views order history.

**Peak load**: Weekly spike when ~5,000 students access simultaneously. Backend must handle burst (queue, cache, rate-limit).

**Student flow**: Browse → filter by stock/category → add to cart → submit order (`status: pending`)

**Order lifecycle**: `pending → confirmed → cancelled`

---

## Stack

JavaScript (ESM) — Node.js/Express backend, React 18 + Vite frontend.

---

## Data Model

**Ingredient** (admin-managed via REST):
```
{ id, name, unit: "kg"|"g"|"L"|"ml"|"pcs", price, stock, category: "Grain"|"Protein"|"Vegetable"|"Dairy"|"Spice" }
```

**Order**:
```
{ id, studentId, items: [{ ingredientId, qty }], placedAt, status: "pending"|"confirmed"|"cancelled" }
```
Tables: `orders`, `order_items`

**User**: `{ id, name, grade, budget }`  
**School**: central budget pool (`crud_market.school`)

---

## API Experiment Plan

**Phase 1 — REST** (current): Full CRUD for `ingredients` + `orders` over HTTP. Baseline.

**Phase 2 — GQL** (alongside REST, same DB): `/graphql` read side only — ingredient filtering + order status queries. These expose REST's over-fetching / round-trip pain. Order submission stays REST.

| Protocol | Scope | Why |
|---|---|---|
| REST | Full CRUD — ingredients + orders | Baseline; HTTP verbs + resource design |
| GQL | Read side — ingredient queries + order status | Contrast: schema-first vs resource-first, same DB |

gRPC: out of scope.

---

## Services

| Service | Stack | Port |
|---|---|---|
| REST API | Express ESM, auto-loads `*.routes.js` | 3001 |
| GraphQL API | Phase 2, single `/graphql` endpoint | 4000 |
| Frontend | React 18 + Vite | 5173 |
| PostgreSQL | Tables: `ingredients`, `orders`, `order_items` | 5432 |

DB current state: in-memory store (`backend/src/models/ingredients.js`), resets on restart.

---

## Key Files

| File | Role |
|---|---|
| `backend/src/main.js` | Express bootstrap — mounts `/api`, health at `/health` |
| `backend/src/routes/index.js` | Auto-loads `*.routes.js`, mounts at `/api/<filename>` |
| `backend/src/models/index.js` | Sequelize registry — exports `db.Ingre`, `db.Order`, `db.User`, `db.Admin` |
| `backend/src/models/ingredient.model.js` | Ingredient model → `crud_market.ingredients` |
| `backend/src/models/order.model.js` | Order model — parallel arrays `ingreId[]` + `qty[]` |
| `backend/src/models/user.model.js` | User model — student + teacher/admin, holds `budget` |
| `backend/src/models/school.model.js` | School model — central budget pool |
| `backend/src/controllers/ingredient.controller.js` | CRUD handlers (admin) |
| `backend/src/controllers/order.controller.js` | Submit + confirm/cancel order; deducts budget on confirm |
| `backend/src/controllers/order-history.controller.js` | Student order history — list, search, edit, bill, export |
| `backend/src/middleware/auth.middleware.js` | JWT validation — sets `req.user`; `requireRole`, `requireClassOwnership` |
| `backend/src/sequelize.js` | Sequelize instance — reads `DATABASE_URL` |
| `backend/src/config.js` | Loads `.env` via dotenv + dotenv-expand |
| `backend/db/create.psql` | DDL — `crud_market` schema + all tables |
| `backend/db/mock.psql` | Seed — school budget, users, Thai ingredients, orders |
| `frontend/src/App.jsx` | Browse → cart → order → confirmation; live API log panel |
| `backend/src/gql/CRUD.gql` | GQL schema stub (Phase 2) |

---

## API Endpoints

### Ingredient Market
| Method | Path | Access | Purpose |
|---|---|---|---|
| GET | `/api/ingredient/ingredient` | Public | List all (filter by category, stock) |
| GET | `/api/ingredient/ingredient/search` | Public | Search by name or id |
| POST | `/api/ingredient/ingredient/create` | Admin (role 2) | Create listing |
| PUT | `/api/ingredient/ingredient/:id` | Admin (role 2) | Update price/stock/name |
| DELETE | `/api/ingredient/ingredient/:id` | Admin (role 2) | Soft-delete |

### Orders
| Method | Path | Access | Purpose |
|---|---|---|---|
| POST | `/api/order/` | Authenticated | Submit order (`status: 0 pending`) |
| PATCH | `/api/order/:id/status` | Teacher/Admin | Confirm or cancel; deducts budget on confirm |

### Order History
| Method | Path | Access | Purpose |
|---|---|---|---|
| POST | `/api/order-history/order/history` | Authenticated | List own orders (paginated) |
| GET | `/api/order-history/order/history/search` | Authenticated | Search by name or id |
| PATCH | `/api/order-history/order/history/:id` | Authenticated (class owner) | Edit — only when `status = 0` |
| GET | `/api/order-history/order/history/:id` | Authenticated | Full bill detail |
| GET | `/api/order-history/order/history/:id/export` | Authenticated | Export PDF or CSV |
| DELETE | `/api/order-history/order/history/:id` | Teacher/Admin + class owner | Delete from history |

---

## Infrastructure

**Local dev (current)**:
```
cd backend && npm run dev   # nodemon, :3001
cd frontend && npm run dev  # Vite, :5173
```
Health: `GET http://localhost:3001/health`

**Target**: Docker Compose — single `docker-compose up` for Postgres + REST + GQL + Frontend.

**Seed**: ~20 Thai ingredients in `backend/src/models/ingredients.js` → target `db/schema.sql` + seed script once Postgres added.
