# Token Blacklist — Future Plan

## Problem

Access token is stateless — after logout, it stays valid until expiry (up to 30 min).
If a token is stolen or a user is force-logged-out, we can't invalidate it immediately.

## Current behavior (Phase 1)

- Logout = delete `refreshToken` from DB
- Access token dies on its own after `JWT_ACCESS_EXP` minutes
- Acceptable for demo / low-risk use case

## Planned approach (Phase 2)

Store revoked `jti` (JWT ID) in Redis with TTL = remaining token lifetime.

### Steps

1. Add `jti: uuid()` to every access token payload at sign time
2. On logout: write `jti` to Redis with `EX = remainingSeconds`
3. In auth middleware: after `jwt.verify()`, check Redis for `jti` → if found, reject 401
4. Redis auto-expires entries → no cleanup needed

### Why Redis not DB

- DB lookup on every request = slow
- Redis O(1) lookup, TTL handled automatically

## Trigger to implement

When any of these become true:
- App handles real student data
- Admin needs force-logout (e.g. compromised account)
- Session duration extends beyond 30 min
