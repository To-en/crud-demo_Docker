# Plan to GQL + auth implemented

**ข้อต่างหลัก:**

| |soc-log-service (ปัจจุบัน)|middleware/guard|
|---|---|---|
|Auth logic|copy-paste ทุก endpoint|เขียนครั้งเดียว|
|ลืม protect endpoint|เป็นไปได้|ไม่เกิด ถ้า global|
|bypass ต่อ endpoint|ง่าย|ต้องใช้ `@SkipAuth()` decorator|
|maintainability|แย่|ดี|

soc-log-service เลือก pattern แรกอาจเพราะ auth logic ไม่ได้ verify JWT เอง — ต้องยิง HTTP ไปถาม external service ก่อน ซึ่งทำให้ guard ซับซ้อนขึ้นนิดนึง แต่ก็ยังทำได้

---

Good picture. `ingre.gql` is empty draft. Ingredient is perfect to convert — clean CRUD, has both public reads + admin writes (good auth demo).

---

## 1. Which endpoint → Ingredient

- Self-contained (no joins to other domains)
- Has read (public) + write (admin-only) → teaches both auth levels
- You already have `ingre.gql` stub started

---

## 2. Files to create/edit

**Install first:**

```bash
npm install @apollo/server graphql
```

**Create these 3 files:**

```
backend/src/gql/
├── ingre.gql          ← already exists, replace content (schema)
├── ingre.resolvers.js ← NEW (resolver functions)
└── index.js           ← NEW (Apollo setup + context)
```

**Edit:**

```
backend/src/main.js    ← mount Apollo alongside Express
```

---

### `ingre.gql` — schema

```graphql
type Ingredient {
  id:       Int!
  name:     String!
  unit:     String!
  stock:    Int!
  category: String!
}

type IngredientPage {
  total: Int!
  page:  Int!
  limit: Int!
  data:  [Ingredient!]!
}

type Query {
  ingredients(page: Int, limit: Int): IngredientPage!
  searchIngredients(q: String, category: String, inStock: Boolean, page: Int, limit: Int): IngredientPage!
}

type Mutation {
  createIngredient(name: String!, unit: String!, stock: Int!, category: String!): Ingredient!
  updateIngredient(id: Int!, name: String!, unit: String!, stock: Int!, category: String!): Ingredient!
  deleteIngredient(id: Int!): Ingredient!
}
```

---

### `ingre.resolvers.js` — reuse existing controller logic

```js
import { Op } from 'sequelize';
import { GraphQLError } from 'graphql';
import models from '../models/index.js';

function requireAuth(context) {
  if (!context.user) throw new GraphQLError('Not authenticated', {
    extensions: { code: 'UNAUTHENTICATED' }
  });
}
function requireAdmin(context) {
  requireAuth(context);
  if (context.user.role !== 2) throw new GraphQLError('Admin only', {
    extensions: { code: 'FORBIDDEN' }
  });
}

export const resolvers = {
  Query: {
    ingredients: async (_, { page = 1, limit = 15 }) => {
      const { count, rows } = await models.Ingre.findAndCountAll({
        offset: (page - 1) * limit, limit,
      });
      return { total: count, page, limit, data: rows };
    },

    searchIngredients: async (_, { q, category, inStock, page = 1, limit = 15 }) => {
      const where = {};
      if (category) where.category = category;
      if (q)        where.name = { [Op.iLike]: `%${q}%` };
      if (inStock)  where.stock = { [Op.gt]: 0 };

      const { count, rows } = await models.Ingre.findAndCountAll({
        where, offset: (page - 1) * limit, limit,
      });
      return { total: count, page, limit, data: rows };
    },
  },

  Mutation: {
    createIngredient: async (_, args, context) => {
      requireAdmin(context);
      return models.Ingre.create(args);
    },

    updateIngredient: async (_, { id, ...fields }, context) => {
      requireAdmin(context);
      const item = await models.Ingre.findByPk(id);
      if (!item) throw new GraphQLError('Not found', { extensions: { code: 'NOT_FOUND' } });
      return item.update(fields);
    },

    deleteIngredient: async (_, { id }, context) => {
      requireAdmin(context);
      const item = await models.Ingre.findByPk(id);
      if (!item) throw new GraphQLError('Not found', { extensions: { code: 'NOT_FOUND' } });
      await item.destroy();
      return item;
    },
  },
};
```

---

### `gql/index.js` — Apollo setup

```js
import { ApolloServer } from '@apollo/server';
import { expressMiddleware } from '@apollo/server/express4';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import path from 'path';
import Jwt from 'jsonwebtoken';
import config from '../config.js';
import models from '../models/index.js';
import { resolvers } from './ingre.resolvers.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const typeDefs = readFileSync(path.join(__dirname, 'ingre.gql'), 'utf8');

export async function buildApolloMiddleware() {
  const server = new ApolloServer({ typeDefs, resolvers });
  await server.start();

  return expressMiddleware(server, {
    context: async ({ req }) => {
      const header = req.headers.authorization;
      if (!header?.startsWith('Bearer ')) return {};

      const token = header.split(' ')[1];

      // dev bypass — same as REST middleware
      if (process.env.NODE_ENV === 'development' && token === process.env.DEV_TOKEN)
        return { user: { id: 1, role: 2 } };

      try {
        const jwt = Jwt.verify(token, config.jwtsecret.access);
        const user = await models.User.findByPk(jwt.id);
        if (!user) return {};
        const plain = user.get({ plain: true });
        delete plain.password;
        return { user: plain };
      } catch {
        return {};
      }
    },
  });
}
```

---

### `main.js` — mount Apollo

```js
import { buildApolloMiddleware } from './gql/index.js';

// after app.use(express.json()) line, add:
app.use('/graphql', await buildApolloMiddleware());
```

---

## 3. How to test

Apollo gives free browser UI at `http://localhost:3000/graphql`.

**Query (no auth needed):**

```graphql
query {
  ingredients(page: 1, limit: 5) {
    total
    data { id name stock category }
  }
}
```

**Mutation (needs auth) — set HTTP header in UI:**

```
Authorization: Bearer <your_token>
```

```graphql
mutation {
  createIngredient(name: "Garlic", unit: "kg", stock: 10, category: "Vegetable") {
    id name stock
  }
}
```

---

## 4. How auth applies — summary

```
HTTP request
└── Authorization: Bearer <token>
      ↓
context fn in gql/index.js   ← verifies token, puts user on context
      ↓
resolver                      ← calls requireAdmin(context) or requireAuth(context)
      ↓
throws GraphQLError if missing/wrong role
```

Key difference from REST: no `router.use(validate)` middleware. Auth check lives **inside each resolver** via the context object.

---

Want me to write these files directly into the project?
