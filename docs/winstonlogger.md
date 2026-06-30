

### Winston logger

logger.js — factory function ส่ง winston logger กลับมา

format output แบบนี้:

15-06-2026 14:30:00 INF [main] Server started
ทำไม (__filename)


module.exports = (filename) => { ... }
รับ filename → เอาไปทำ label ใน log:


defaultMeta: { label: path.basename(filename, ".js") }
แต่ละ file import logger แบบนี้:


const logger = require("./logger")(__filename)
__filename = path เต็มของ file นั้น เช่น /app/src/main.js

path.basename(..., ".js") → "main"

ผลคือ log บอกว่า มาจาก file ไหน โดยอัตโนมัติ — ไม่ต้อง hardcode label เอง