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


**1. สร้าง Context + Provider** ← มีแล้วใน [auth.context.jsx](vscode-webview://0l35c22pd5fj62atfanmda0aifrqdbcj8kbb1q02i31cqgn0kmba/frontend/src/context/auth.context.jsx)

```js
const AuthContext = createContext(null)
export function AuthProvider({ children }) { ... }
export function useAuth() { return useContext(AuthContext) }
```

---

**2. Wrap app ด้วย Provider** ← ยังไม่ได้ทำ ต้องเพิ่มใน [main.jsx](vscode-webview://0l35c22pd5fj62atfanmda0aifrqdbcj8kbb1q02i31cqgn0kmba/frontend/src/main.jsx)

```jsx
import { AuthProvider } from "./context/auth.context";

ReactDOM.createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <AuthProvider>   {/* ← wrap ตรงนี้ */}
      <App />
    </AuthProvider>
  </React.StrictMode>
);
```

---

**3. ใช้ใน component ไหนก็ได้** ที่อยู่ข้างใน Provider

```jsx
import { useAuth } from "../context/auth.context";

function Navbar() {
  const { user, isLoggedIn } = useAuth();
  return <div>{isLoggedIn ? user.name : "Guest"}</div>
}
```

---

กฎเดียว: component ที่ `useAuth()` ต้องอยู่ **ข้างใน** `<AuthProvider>` ใน tree — ถ้าอยู่นอกจะได้ `null` กลับมา