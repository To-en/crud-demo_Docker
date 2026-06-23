# Topic A — API Experiment Plan

## Phase 1: REST (current focus)
Full CRUD for `ingredients` + `orders`. Swap in-memory store → Postgres.

**Endpoints to build:**
- `GET/POST /api/ingredients` — list, create
- `GET/PUT/DELETE /api/ingredients/:id` — get, update, delete
- `POST /api/orders` — student submits order (checks balance, deducts on confirm)
- `GET /api/orders/:id` — order status
- `PATCH /api/orders/:id/confirm` — admin confirms, deducts student balance
- `PATCH /api/orders/:id/cancel`
- `POST /api/students/:id/topup` — admin tops up balance (seam for future auth)

## Phase 2: GQL (alongside REST, same DB)
Read-side only. Add `/graphql` endpoint.
- Query: ingredients (filter by category, inStock)
- Query: order status by student
- No GQL mutations — writes stay REST

---

# Topic B — Payment / Balance Design

## Decision: school-allocated balance (no payment gateway)
Student has a fixed weekly budget set by admin. No Stripe, no mobile banking.

**Student model addition:**
```
{ id, name, grade, balance: number }
```

**Order confirm logic:**
```
if student.balance < order.total → 400 reject
else → deduct balance, status = "confirmed"
```

## Cashflow seam (defer until auth phase)

| Now | Later (auth phase) |
|---|---|
| `studentId` hardcoded / mock | Real login, JW (Login) |
| Admin topup via REST stub | Admin dashboard, bulk topup |
| No audit trail | Transaction log table |

**Do now:** add `balance` field to Student, stub `POST /api/students/:id/topup`. Leave the seam clean.
**Defer:** login, auth, admin accounts, transaction history.

---
Login idea
user = Group_xx_classxx, student fill the xx -> May becomes drop down with optional typing
password = pure text typing 
