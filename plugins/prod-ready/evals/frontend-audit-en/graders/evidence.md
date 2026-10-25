---
type: llm
weight: 2
---
The final message is a readiness audit report with a table of items and statuses. PASS if every row whose status is passed (✅ or PASS) states concrete evidence for passing (a file:line reference, a quoted config value, the scope that was scanned, or a command result). PASS also if there are no passed rows. FAIL only if some row is marked passed with no evidence at all, or only a guess such as "probably" or "likely".
