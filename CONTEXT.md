# Ingredient Ordering — CRUD Demo

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

## Protocol → Domain Mapping

| Protocol | Serves | Reason |
|---|---|---|
| REST | Ingredient CRUD (admin) + Order management | Resource-first; easy to demo HTTP verbs |
| GQL | Meal planning query (student) | Flexible filtering, nested ingredient+order queries; schema-first contrast to REST |
| gRPC | Order submission at peak | High-throughput streaming; handles 5k weekly burst |

**Resource vs Schema**: REST organises around resource nouns (`/ingredients`, `/orders`). GQL organises around a typed schema (graph of entities). Same data, different mental model — core comparison of the experiment.
_Avoid_: "endpoint-driven vs query-driven" (too abstract without context)

---

## Services

**REST API** (`backend/`, Express ESM, port `3001`):
Auto-loads `*.routes.js` from `src/routes/`. CORS enabled. Baseline for comparing API styles. Endpoints: `/crud/ingredients`, `/orders` (planned).
_Avoid_: "RESTful microservice"

**GraphQL API** (planned, port `4000`):
Single `/graphql` endpoint. Queries + mutations mirror REST operations. Students see how schema-first differs from route-first. Same DB.
_Avoid_: "GraphQL gateway", "federation"

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
| `backend/src/models/ingredients.js` | In-memory store + seed data. Exports `ingredients[]`, `bumpId()` |
| `backend/src/routes/crud.routes.js` | REST CRUD for `/crud/ingredients` |
| `backend/src/routes/index.js` | Auto-loads `*.routes.js`, mounts at `/<name>` |
| `backend/src/main.js` | Bootstrap: Express, health check at `/health` |
| `frontend/src/App.jsx` | Ingredient list, CRUD form, ApiLog, toasts |
| `backend/src/gql/CRUD.gql` | GQL schema stub (empty — next phase) |
| `backend/src/proto/a.proto` | gRPC proto stub (empty — next phase) |

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
