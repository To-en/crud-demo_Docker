# Plan: Frontend Auth Context + Learning Doc

## Context
Backend auth is wired. Frontend needs: AuthContext (token storage + login/logout/refresh), PrivateRoute guard, login form, and auto-attach token to API calls. User wants a learning doc explaining the why behind each piece.

## Files to create/modify

### 1. `docs/frontend-auth-walkthrough.md` (new)
Learning doc covering:
- Why context over prop-drilling
- localStorage vs memory for tokens (tradeoffs)
- How `getAccessToken()` auto-refresh works
- What `PrivateRoute` does and why
- How every API call gets the token automatically

### 2. `frontend/src/context/auth.context.jsx`
Implement:
```
AuthProvider:
  state: user (decoded payload) | null
  localStorage keys: "accessToken", "refreshToken"

  login(username, password):
    POST /api/login → { accessToken, refreshToken }
    save both to localStorage
    decode accessToken with atob() → setUser({ id, role })

  logout():
    remove tokens from localStorage
    setUser(null)

  getAccessToken():
    read accessToken from localStorage
    decode exp → if expired → POST /api/refresh → save new token
    return accessToken

  value: { user, isLoggedIn, login, logout, getAccessToken }
```

### 3. `frontend/src/App.jsx`
Add `<AuthProvider>` wrapping all routes.
Add `<PrivateRoute>` component:
```
if (!isLoggedIn) → <Navigate to="/login" replace />
else → <Outlet />
```
Wrap protected routes: `/cart`, `/order-history`, `/ingredients` (CRUD pages)
Keep `/market` and `/login` public.

### 4. `frontend/src/pages/login.page.jsx`
Add form: username + password fields + submit button.
On submit → `login(username, password)` from useAuth() → navigate to `/market`.
On error → show error message.

### 5. `frontend/src/utils/api.js`
All API calls go through here. Each call:
```
const token = await getAccessToken()
fetch(url, { headers: { Authorization: `Bearer ${token}` } })
```

## Verification
1. Open `/market` → no redirect (public)
2. Open `/cart` → redirect to `/login`
3. Login with valid creds → redirect to `/market`
4. Open `/cart` → accessible
5. Wait 30min or manually expire token → next API call auto-refreshes silently
6. Logout → `/cart` redirects to `/login` again
