# Winston Logger — how it works (read-me-later guide)

Written so a future me who forgot all web dev can rebuild the mental model in 10 minutes.
Logging = write timestamped messages to the terminal **and** to files, filtered by importance.
Two libraries do it here: **winston** (the logger) + **morgan** (auto-logs every HTTP request).

---

## The one-paragraph summary

Each source file makes its own logger by calling `makeLogger(import.meta.url)`. That returns a
winston logger tagged with the filename. You call `logger.error/warn/info/http/debug(msg)`.
Each call fans out to **all transports** (the console + `logs/combined.log` + `logs/error.log`)
that accept that severity. What gets through is decided by a **threshold** (`LOG_LEVEL` in `.env`).

---

## Step 1 — Levels: what "importance" means

Winston ranks levels by number. **Lower number = more severe.**

```
error:0   warn:1   info:2   http:3   verbose:4   debug:5   silly:6
```

You pick the level **at the call site**, based on what happened:

| Call | Use when |
|------|----------|
| `logger.error()` | caught exception, a 500, something broke |
| `logger.warn()`  | handled but suspicious (bad login, role denied, auth bypass) |
| `logger.info()`  | normal milestone (server started, route loaded) |
| `logger.http()`  | one HTTP request (morgan uses this — you rarely call it yourself) |
| `logger.debug()` | dev-only detail (rejected token, SQL query dumps) |

---

## Step 2 — The threshold (`LOG_LEVEL`) decides what actually prints

The logger has ONE threshold. **A message shows only if its number ≤ the threshold's number**
(i.e. equal or MORE severe). Everything less severe is silently dropped.

`.env` sets it: `LOG_LEVEL=debug` (current). `config.js` reads it into `config.log.level`,
and `logger.js` passes it to `createLogger({ level: config.log.level })`.

| LOG_LEVEL | you see | you don't see |
|-----------|---------|---------------|
| `error`   | error | warn, info, http, debug |
| `warn`    | error, warn | info, http, debug |
| `info`    | error, warn, info, http | debug |
| `debug`   | **everything** | — |

Key idea: **you leave the `logger.debug()` calls in the code forever.** In prod you just set
`LOG_LEVEL=warn` and they go quiet — no code change. Threshold is the volume knob.

### Threshold is per-logger, but each transport can tighten it

The logger-wide `level` is the baseline. A single transport may set its **own** stricter level.
It can only filter *more*, never loosen below the logger baseline. Example in this repo:

- logger baseline = `debug` → combined.log gets everything.
- `error.log` transport has `level: "error"` → that file keeps errors only.

So the effective filter for a file = the stricter of (logger level, that transport's level).

---

## Step 3 — Transports: the same message goes to many places

A **transport** is a destination. `logger.warn("x")` is written **once** by you, then winston
copies the finished line to every transport that passes the level check. This repo has three:

```js
transports: [
  new transports.Console({ ... }),                       // terminal, colorized
  new transports.File({ filename: "logs/combined.log" }),// everything (plain text)
  new transports.File({ filename: "logs/error.log", level: "error" }), // errors only
]
```

`filename`/directory is a property of each **File transport**, not the logger. Want a third log
file? Add another File transport with its own filename + optional level.

Note: colorize writes invisible ANSI escape codes — great in a terminal, garbage in a file.
That's why colorize lives only on the **Console** transport; files get plain text.

---

## Step 4 — Format: how a call becomes a line of text

`format.combine(...)` is a **pipeline**. Every log call builds one `info` object and pushes it
through each stage in order. Each stage adds/changes a field. The last stage (`printf`) turns the
object into the final string:

```
logger.warn("user %s denied", 5)
      │
      ▼  start:  { level:"warn", message:"user %s denied", label:"auth.middleware" }
      │          (label comes from defaultMeta, set per-file in makeLogger)
      │
      │  format.timestamp()  → adds  info.timestamp = "2026-07-01T14:08:21.000Z"
      │  format.splat()      → expands %s  → message = "user 5 denied"
      │  customFormat (printf)→ returns the string below
      ▼
"01-07-2026 14:08:21 WRN [auth.middleware] user 5 denied"
```

**How does `customFormat` get its arguments?** You never call it. Winston calls it last, once per
line, and hands it that accumulated `info` object. Your printf just destructures the fields it
wants:

```js
const customFormat = format.printf(({ level, message, label, timestamp }) => {
  timestamp = dayjs(timestamp).format("DD-MM-YYYY HH:mm:ss"); // pretty date
  level = customLevel(level);                                 // error→ERR, warn→WRN, ...
  return `${timestamp} ${level} [${label}] ${message}`;
});
```

- `level`, `message` — from the `.warn(...)` call itself
- `label` — from `defaultMeta: { label }` (the filename)
- `timestamp` — injected by the `format.timestamp()` stage **before** printf

**Order matters:** `timestamp()` and `splat()` must sit before `customFormat`, or `info.timestamp`
is undefined and `%s` isn't expanded when printf runs.

---

## Step 5 — Why `makeLogger` is a factory (returns a logger, not a logger)

`logger.js` exports a **function** `(filename) => Logger`, not a ready logger. Reason: each file
wants its own **label** so log lines say which file they came from. So every file does:

```js
import makeLogger from './logger.js';
const logger = makeLogger(import.meta.url);   // label = "order.controller", etc.
```

`import.meta.url` is the current file's path; `makeLogger` strips it down to the basename for the
`[label]`. (Gotcha this repo already hit: calling `makeLogger.info(...)` on the factory itself
crashes — you must call the factory first, then use the returned `logger`.)

---

## Step 6 — Using it in any file

```js
import makeLogger from '../logger.js';
const logger = makeLogger(import.meta.url);

logger.error("payment failed: %s", err.message);  // %s filled by format.splat
logger.warn("low stock for %s", name);
logger.info("order %d created", orderId);
logger.debug(sqlDump);                             // hidden unless LOG_LEVEL=debug
```

Discipline used in this codebase:
- **every `catch` that returns 500** → one `logger.error` first (else prod bugs are invisible).
- **expected auth failures** (bad/expired token, missing header) → `logger.debug` (noisy, normal).
- **security-relevant** (DEV_TOKEN bypass, role denied, valid token but user gone) → `logger.warn`.
- **success cases** → mostly skip; morgan already logs `201 POST /order 45ms`.

---

## Step 7 — morgan: automatic HTTP request logging

You don't want to hand-log every endpoint. morgan is Express middleware that logs **one line per
request** automatically. It's wired to feed winston (not print on its own) via a fake stream:

```js
const httpLogger = morgan(
  (tokens, req, res) => JSON.stringify({
    method: tokens.method(req, res),
    url: tokens.url(req, res),
    status: Number(tokens.status(req, res)),
    length: tokens.res(req, res, 'content-length'),
    ms: Number(tokens['response-time'](req, res)),
  }),
  { stream: { write: (msg) => logger.http(msg.trim()) } },  // pipe into winston at http level
);
app.use(httpLogger);
```

Result line: `... http [main] {"method":"GET","url":"/","status":200,"ms":2.48}`.
Because it's `http` level (3), it's hidden if `LOG_LEVEL` is `warn`/`error`.

---

## Step 8 — Run/session separators

`main.js` writes a divider on boot so each server run is visible in the log file:

```js
logger.info("─".repeat(20) + " SERVER START " + "─".repeat(20));
```

Files are **append** mode, so runs stack up; the `SERVER START` line tells you where a new run began.

---

## Quick reference — the moving parts

| Thing | Where | Job |
|-------|-------|-----|
| `LOG_LEVEL` | `backend/.env` | the threshold (volume knob) |
| `config.log.level` | `config.js` | reads LOG_LEVEL |
| `makeLogger(url)` | `logger.js` | factory → per-file labelled logger |
| `customFormat` | `logger.js` | printf that builds the final line |
| transports | `logger.js` | console + combined.log + error.log |
| `httpLogger` (morgan) | `main.js` | auto-log every request at `http` level |
| `logs/` | `backend/logs/` | output files (gitignored) |

## Verify it works

1. `cd backend && npm run dev` → colored `SERVER START` + `route loaded` lines in terminal.
2. Hit an endpoint (`GET /`) → an `http` JSON line appears.
3. `cat logs/combined.log` → same lines, plain text (no color codes).
4. Trigger a 500 → line appears in **both** combined.log and error.log.
5. Set `LOG_LEVEL=warn`, restart → `debug`/`http` lines vanish, warn/error remain. No code change.
</content>
