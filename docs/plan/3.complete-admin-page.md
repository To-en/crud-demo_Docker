# Handoff — `frontend/src/pages/admin.page.jsx`

**Scope: this file only.** Admin ingredient CRUD (role 2). UI + list fetch already scaffolded and building. Three gaps left, all backend wiring.

## State now
- `IngredientForm` (name/category/unit/price/stock) — done, renders, validates.
- `fetchItems` GET list — done.
- Table list + Add/Edit toggle + ApiLog + Toasts — done.
- `handleSubmit` — stub (`toast("TODO")`).
- Delete button — disabled, no handler.
- No auth token threaded → writes will 401.

## Endpoints (from `frontend/public/config.json`)
| Action | Method | Path |
|---|---|---|
| List | GET | `config.API_ENDPOINT_INGREDIENT` (`/api/ingredient`) |
| Create | POST | `config.API_ENDPOINT_INGREDIENT_CREATE` (`/api/ingredient/create`) |
| Update | PUT | `` `${config.API_ENDPOINT_INGREDIENT}/${id}` `` (`/api/ingredient/:id`) |
| Delete | DELETE | `` `${config.API_ENDPOINT_INGREDIENT}/${id}` `` (`/api/ingredient/:id`, permanent) |

`requestHTTP(method, path, body, onLog, token)` — already imported. Pass `addLog` as `onLog`.

## Tasks
1. **Auth token** — pull from `useAuth()` (`../context/auth.context`). Token lives on `user.accessToken` (see `auth.context.jsx` setUser shape). Pass as 5th arg to `requestHTTP` on create/update/delete. List is public, no token.
2. **`handleSubmit(form)`** — split create vs update on `isEdit`/`formMode`:
   - create → POST CREATE, append to `items`.
   - update → PUT `:id` (`formMode.id`), replace in `items`.
   - set `formLoading` around call, `setFormMode(null)` + success toast on done, error toast on catch.
3. **Delete handler** — DELETE `:id`, drop from `items`, confirm first (permanent). Wire to the disabled Delete button; add per-row deleting state for spinner.

## Watch
- List response shape unconfirmed — code guards `Array.isArray(data) ? data : data.items ?? []`. Verify against real backend, fix if paginated wrapper differs.
- `auth.context` has no session persistence → token gone on refresh. Out of scope here; if admin testing breaks on reload, that's why.
- Backend known bug (CONTEXT): ingredient GET behind `validate` wall — backend task, not this file.
