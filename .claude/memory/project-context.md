---
name: project-context
description: CRUD experiment project — ingredient ordering app for secondary school students, REST + GraphQL implementations
metadata:
  type: project
---

Project is a **CRUD experiment**: same ingredient ordering domain implemented across REST and GraphQL backends to compare API styles hands-on. gRPC only if user prompts.

**Why:** User wants to learn backend principles through direct comparison, not just tutorial code.
**How to apply:** When suggesting implementation, always tie it back to the comparison — "in REST you do X, in GraphQL the equivalent is Y."

Domain: students browse ingredients (app acts as a market), submit lunch orders. ~5,000 users total; traffic spikes once a week when nearly all access simultaneously.

DB: PostgreSQL. Tables: `ingredients`, `orders`, `order_items`. Must handle ~5,000 concurrent reads on peak day. Design for future scale.

Stack (to be decided): Node/Express or Go for REST; Apollo or similar for GraphQL; React or Next.js for frontend; Docker Compose for local dev.

Seed data: ~20 sample ingredients (name, price, unit, stock count). Schema in `db/schema.sql` or migrations.

Frontend scope: UX walkthrough from ingredient browsing → order form → confirmation, integrated first with REST then compared with GraphQL.
