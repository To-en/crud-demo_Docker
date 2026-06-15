# Graph Report - .  (2026-06-16)

## Corpus Check
- Corpus is ~4,111 words - fits in a single context window. You may not need a graph.

## Summary
- 95 nodes · 100 edges · 15 communities (10 shown, 5 thin omitted)
- Extraction: 88% EXTRACTED · 12% INFERRED · 0% AMBIGUOUS · INFERRED: 12 edges (avg confidence: 0.82)
- Token cost: 8,000 input · 2,900 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Frontend UI Components|Frontend UI Components]]
- [[_COMMUNITY_Backend Dependencies|Backend Dependencies]]
- [[_COMMUNITY_Backend API & Data Layer|Backend API & Data Layer]]
- [[_COMMUNITY_Frontend Dependencies|Frontend Dependencies]]
- [[_COMMUNITY_Project Docs & Domain Concepts|Project Docs & Domain Concepts]]
- [[_COMMUNITY_REST CRUD Architecture|REST CRUD Architecture]]
- [[_COMMUNITY_Logger Module|Logger Module]]
- [[_COMMUNITY_Claude Memory Files|Claude Memory Files]]
- [[_COMMUNITY_Claude Hook Settings|Claude Hook Settings]]
- [[_COMMUNITY_Vite Build Config|Vite Build Config]]
- [[_COMMUNITY_Claude Settings & Graphify|Claude Settings & Graphify]]
- [[_COMMUNITY_Frontend Package Config|Frontend Package Config]]
- [[_COMMUNITY_Inquiry Notes|Inquiry Notes]]

## God Nodes (most connected - your core abstractions)
1. `App()` - 9 edges
2. `Ingredient Ordering Domain Model` - 7 edges
3. `CONTEXT.md Project Overview` - 6 edges
4. `Express App Entry Point` - 4 edges
5. `Ingredients In-Memory Data Store` - 4 edges
6. `CRUD Ingredients Router` - 4 edges
7. `Project Context` - 4 edges
8. `API Protocol Comparison (REST vs GQL vs gRPC)` - 4 edges
9. `scripts` - 3 edges
10. `ingredients` - 3 edges

## Surprising Connections (you probably didn't know these)
- `App()` --conceptually_related_to--> `API Protocol Comparison (REST vs GQL vs gRPC)`  [INFERRED]
  frontend/src/App.jsx → CONTEXT.md
- `In-Memory Data Store (No DB Yet)` --conceptually_related_to--> `Project Context`  [INFERRED]
  backend/src/models/ingredients.js → .claude/memory/project-context.md
- `Project Context` --conceptually_related_to--> `Ingredient Ordering Domain Model`  [INFERRED]
  .claude/memory/project-context.md → backend/src/models/ingredients.js
- `Ingredient Ordering Domain Model` --conceptually_related_to--> `Order Lifecycle`  [INFERRED]
  backend/src/models/ingredients.js → CONTEXT.md
- `Project README` --semantically_similar_to--> `CONTEXT.md Project Overview`  [INFERRED] [semantically similar]
  README.md → CONTEXT.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **REST CRUD Request Flow: Router -> Model -> Response** — src_main_js, routes_index_js, routes_crud_routes_js, models_ingredients_js [INFERRED 0.95]
- **Claude Agent Memory Context: User Profile + Communication + Project** — memory_user_profile_md, memory_feedback_communication_md, memory_project_context_md [EXTRACTED 1.00]
- **Frontend CRUD Flow: Form → Request → API → State Update** — src_app_ingredientform, src_app_request, src_app_app, concept_ingredient_domain [INFERRED 0.85]
- **Teaching Tool: API Observability (Log Panel + Toasts + Live State)** — src_app_apilog, src_app_toasts, concept_api_log_panel, src_app_app [INFERRED 0.80]
- **Protocol-to-Domain Mapping: REST/GQL/gRPC covering Ingredient+Order+PeakLoad** — concept_api_protocol_comparison, concept_ingredient_domain, concept_order_lifecycle, concept_peak_load [EXTRACTED 0.95]

## Communities (15 total, 5 thin omitted)

### Community 0 - "Frontend UI Components"
Cohesion: 0.20
Nodes (12): Live API Log Panel, Frontend index.html, Frontend README, ApiLog(), App(), CATEGORIES, CATEGORY_EMOJI, IngredientForm() (+4 more)

### Community 1 - "Backend Dependencies"
Cohesion: 0.15
Nodes (12): dependencies, cors, dotenv, express, nodemon, main, name, scripts (+4 more)

### Community 2 - "Backend API & Data Layer"
Cohesion: 0.19
Nodes (9): bumpId(), ingredients, CATEGORIES, router, UNITS, __dirname, files, rootRouter (+1 more)

### Community 3 - "Frontend Dependencies"
Cohesion: 0.15
Nodes (12): dependencies, react, react-dom, devDependencies, vite, @vitejs/plugin-react, main, name (+4 more)

### Community 4 - "Project Docs & Domain Concepts"
Cohesion: 0.24
Nodes (10): Backend README, BUFFER.md Short-term Memory, CLAUDE.md Project Instructions, API Protocol Comparison (REST vs GQL vs gRPC), Ingredient Ordering Domain Model, Order Lifecycle, Peak Load Design Constraint, CONTEXT.md Project Overview (+2 more)

### Community 5 - "REST CRUD Architecture"
Cohesion: 0.28
Nodes (9): Backend Package JSON, REST CRUD Pattern for Ingredients, Dynamic Route Auto-discovery Pattern, In-Memory Data Store (No DB Yet), Ingredients In-Memory Data Store, CRUD Ingredients Router, Dynamic Route Loader (Root Router), Logger Module (+1 more)

### Community 6 - "Logger Module"
Cohesion: 0.29
Nodes (5): config, { createLogger, transports, format, Logger }, customFormat, dayjs, path

### Community 7 - "Claude Memory Files"
Cohesion: 0.83
Nodes (4): Feedback Communication Preferences, Memory Index, Project Context, User Profile

## Knowledge Gaps
- **46 isolated node(s):** `PreToolUse`, `name`, `version`, `type`, `main` (+41 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **5 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Ingredient Ordering Domain Model` connect `Project Docs & Domain Concepts` to `Frontend UI Components`, `REST CRUD Architecture`, `Claude Memory Files`?**
  _High betweenness centrality (0.088) - this node is a cross-community bridge._
- **Why does `App()` connect `Frontend UI Components` to `Project Docs & Domain Concepts`?**
  _High betweenness centrality (0.080) - this node is a cross-community bridge._
- **Are the 3 inferred relationships involving `Ingredient Ordering Domain Model` (e.g. with `Backend README` and `Order Lifecycle`) actually correct?**
  _`Ingredient Ordering Domain Model` has 3 INFERRED edges - model-reasoned connections that need verification._
- **Are the 2 inferred relationships involving `Express App Entry Point` (e.g. with `Logger Module` and `Backend Package JSON`) actually correct?**
  _`Express App Entry Point` has 2 INFERRED edges - model-reasoned connections that need verification._
- **What connects `PreToolUse`, `name`, `version` to the rest of the system?**
  _50 weakly-connected nodes found - possible documentation gaps or missing edges._