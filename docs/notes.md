### Backend and frontend project structur pattern

Either write evertthing in one
main.js
main.jsx


Or split the main one to 

router.js -> Mount to main.js
or App.js -> compile all pages and components ->



Especially @CONTEXT.md , I will edit later anyways but,
Let's write
---
The project is personal to me , but for now just say it was ingredient ordering webapp for high school student to learn how to cook on every day , so the customer needs a clear , easy and fast to use app.
Student must planned their meal by looking at the avaialbel ingredient list. And the 


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