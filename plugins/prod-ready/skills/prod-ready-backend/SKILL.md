---
name: prod-ready-backend
description: Use when writing or reviewing backend/API code that handles auth, login, sessions, tokens, permissions, user data, SQL, file uploads, secrets or admin features; and when asked whether a backend is ready for production, go-live or launch ("is it production ready", "pre-launch checklist", "security audit", "prod'a hazır mı", "production'a çıkmadan önce kontrol et", "güvenlik kontrolü").
---

# Prod-Ready Backend

## Overview
A 39-item security and operations checklist for a backend that is about to go to production. Stack-agnostic. Two modes:

- **Build mode:** while writing code, the relevant items are the default behavior. Apply them even if nobody asked.
- **Audit mode:** every item is scored with evidence and the report ends with a GO / NO-GO verdict.

Item details (why, how to verify, pass criteria) are in [references/checklist.md](references/checklist.md). Stack-specific code:

- [references/stack-dotnet.md](references/stack-dotnet.md)
- [references/stack-node.md](references/stack-node.md)

For the frontend side use the `prod-ready-frontend` skill.

## Choosing the mode
- Writing or changing an endpoint, auth, a query, an upload or config → **Build mode**.
- "Is it ready / audit / check / review" → **Audit mode**.

## Build mode
Apply the items for the area you are touching. Use the pattern from the reference file that matches the project's stack.

| What you are writing | Items to apply |
|---|---|
| Login / register / password reset | B01–B09, B15, B21, B22, B25, B26, B31 |
| New endpoint | B10–B16, B26, B29 |
| Endpoint returning a resource (`/x/:id`) | B11 (ownership filter inside the query) |
| Update endpoint | B13 (DTO allowlist) |
| Code making outbound HTTP requests | B18 |
| File upload | B27 |
| Config, secrets, deploy | B23–B25, B28, B30, B32 |
| Admin feature | B09, B12, B14, B31 |

If you deliberately deviate from an item, leave a comment with the reason: `// security: <item> not applied because <reason>; <when it will be fixed>`.

## Audit mode
1. Detect the stack and read the matching reference file.
2. Read `references/checklist.md`. **Every ID from B01 to B39 must appear as one row in the report.** A missing row means the report is incomplete.
3. Look for evidence for each item. Evidence is a `file:line` reference or the output of a command you ran.
4. Fill in the report using the template below.

**Statuses:**
- ✅ Pass: evidence can be shown from the code.
- ❌ Fail: there is a gap.
- ⚠️ Partial: partly implemented.
- ➖ N/A: the item does not apply to this project. State the reason (e.g. "no cookie auth, CSRF not applicable").
- ❓ Manual: cannot be verified from code. Infrastructure, process and external-account items go here: backup restore, DB network access, MFA, monitoring, branch protection.

**No evidence, no ✅.** Writing "probably exists" means ❓.

**Scoring rules:**
- **Mixed items:** part of an item may be verifiable from code and part not (e.g. B23: HSTS is visible in code, proxy TLS settings are not). Score the worst status among the verifiable parts. Add the unverifiable part to the ❓ section as a question.
- **Missing features:**
  - If the item describes a safeguard that is needed even when the feature is absent, give ❌. Examples: logout/revocation (B04), MFA when an admin role exists (B09), audit log (B31).
  - If the feature itself is optional and absent, give ➖ with the note "must be applied if added". Example: password reset flow (B08).
- **In-app auth and MFA:** if auth is implemented in the app and there is no MFA code, B09 is ❌. B09 may be ❓ only when auth lives in an external IdP.
- **No lockfile** → B36 is ❌. The "command could not run → ⚠️" rule applies only when a lockfile exists.
- **Secret values:** never print a value in the report or the terminal. Use only the prefix (`sk_live_…`) or a qualifier such as "default/weak". If you must compare a value, use a command that produces no output.
- **Rotation:** treat a secret as leaked and recommend "rotate first" if it sits in plain text in a non-ignored file in the project directory, is in git history, or can be read from a public endpoint.
- **Library and framework defaults count as evidence** (e.g. helmet 7's HSTS and nosniff, ASP.NET's `UseExceptionHandler`), provided the version in use is known. If the version is unknown, give ⚠️.
- **Settings that can live outside the code:** if something can be configured outside the code and is absent from the code, that part is ❓, not ❌. Examples: DB TLS can be enforced with the `PGSSLMODE` env var or server-side; the HTTPS redirect can be done at the proxy.
- **No cookies:** B21 and B25 are ➖. Write "depends on B02" as the reason.
- **B10 in Express:** public routes count as "explicitly marked" if they are defined before the global auth middleware or live in a separate public router. With per-route auth only, list every route. If unauthenticated routes are not marked public anywhere → ❌.
- **Evidence of absence:** if you give ✅ because something is absent (e.g. B19), state the scope you scanned in the evidence column: "all files read (N lines)" or "`<pattern>` over `src/**`, 0 matches".
- **Same root cause:** if one finding violates several items, give ❌ in each. In "Fix first", list it as a single task.
- **Version CVEs** are scored under B36. For other items affected by the CVE (e.g. jsonwebtoken → B05), mention it only in the fix column.
- **Scope:** you may read frontend code to gather evidence (e.g. localStorage use for B02). Put frontend findings under "Additional findings".

**Language:** write the report in the language the user wrote in; table headings may be translated too. If the user's or the environment's instructions forbid emoji, use these status labels: PASS / FAIL / PARTIAL / N/A / MANUAL.

**Tools that cannot run:** if `npm audit`, `curl`, `gitleaks` or similar cannot run, score from source code and list the command that should be run in the ❓ section.

**Severity:**
- BLOCKER: stops the launch.
- HIGH: must be closed within the first week.
- MEDIUM: improvement.

**Verdict rule:**
- Any BLOCKER ❌ or ⚠️ → **NO-GO**.
- Any BLOCKER ❓, or any HIGH ❌/⚠️ → **GO (conditional)**. List the conditions under "Fix first": for each BLOCKER ❓ who verifies it, for each HIGH a closing date (no later than one week after launch).
- Otherwise → **GO**.

**"Fix first" order:**
1. Rotate leaked secrets
2. Gaps exploitable without authentication
3. Gaps exploitable by a logged-in user
4. Everything else

Under deadline pressure, state plainly that the first two groups are not negotiable.

### Report template
```
## Backend Production Readiness — <project> — <date>
**Verdict: NO-GO | GO (conditional) | GO** — <one-sentence reason>
Summary: BLOCKER x❌ y⚠️ z❓ · HIGH x❌ y⚠️ z❓ · MEDIUM x❌ y⚠️ z❓ · ✅ n · ➖ n

| ID | Item | Severity | Status | Evidence | Fix |
|----|------|----------|--------|----------|-----|
| B01 | Password hashing | BLOCKER | ❌ | api/server.js:32 md5 | Move to argon2id, rehash on login |
... (B01–B39, none missing)

### ❓ To verify manually (ask the owner)
- B35: When was the last restore test? What are the RPO/RTO?

### Additional findings (not on the list)
- <anything important outside the checklist: broken build, logic bugs, etc.>

### Fix first
1. <rotate leaked secrets first, if any>
```

## Checklist
| ID | Severity | Item |
|---|---|---|
| **A. Authentication** |||
| B01 | BLOCKER | Passwords hashed with Argon2id/bcrypt. No MD5/SHA/plain text. |
| B02 | BLOCKER | Token in an httpOnly + Secure + SameSite cookie, not in localStorage or a JSON body. SPAs use a BFF. |
| B03 | BLOCKER | Access token lives 5–15 min. Refresh token rotation with reuse detection; refresh tokens stored hashed. |
| B04 | BLOCKER | Logout and password change revoke sessions server-side. |
| B05 | BLOCKER | JWT algorithm pinned (`none` rejected). iss/aud/exp validated. Secret ≥256 bits and random. |
| B06 | BLOCKER | Per-IP and per-account attempt limits on login, register, password reset and OTP, with backoff or temporary lockout. |
| B07 | HIGH | Generic error messages. Whether a user exists cannot be inferred from the message, status code or response time. |
| B08 | HIGH | Password reset token is single-use, short-lived and stored hashed. |
| B09 | HIGH | MFA required for admin and privileged accounts. |
| **B. Authorization** |||
| B10 | BLOCKER | Deny by default: auth applied globally, public endpoints explicitly marked. |
| B11 | BLOCKER | IDOR protection: every query filtered by user/tenant. Access to someone else's resource returns 404. |
| B12 | BLOCKER | Role and userId never taken from headers, body or query; they come from the verified session. |
| B13 | HIGH | No mass assignment. DTO allowlists; `role`/`isAdmin`/`ownerId`/`password_hash` are never bound. |
| B14 | HIGH | Admin: separate role + MFA + audit log, with IP allowlist or VPN as an extra layer. |
| **C. Input and injection** |||
| B15 | BLOCKER | Server-side schema validation (type, length, format). Client-side validation is UX only. |
| B16 | BLOCKER | SQL is parameterized. No string concatenation. ORDER BY and column names come from an allowlist. |
| B17 | HIGH | No other injection: OS command, NoSQL operator, path traversal, template injection. |
| B18 | HIGH | SSRF protection: user-supplied URLs pass an allowlist; private IPs and 169.254.169.254 blocked; DNS rebinding handled. |
| B19 | HIGH | No unsafe deserialization. |
| B20 | HIGH | User HTML is sanitized. Correct Content-Type; user content is never served as `text/html`. |
| **D. Browser and transport** |||
| B21 | BLOCKER | With cookie auth, CSRF protection exists (SameSite + token/custom header). GET requests have no side effects. |
| B22 | BLOCKER | CORS uses an origin allowlist. No `*` with credentials, no origin reflection. |
| B23 | BLOCKER | HTTPS everywhere, HTTP→HTTPS redirect, TLS 1.2+, HSTS on. |
| B24 | HIGH | Security headers: CSP, nosniff, frame-ancestors, Referrer-Policy, Permissions-Policy. `X-Powered-By` removed. |
| B25 | HIGH | Cookies use the `__Host-` prefix, HttpOnly, Secure, SameSite and a sensible Max-Age. |
| **E. Abuse** |||
| B26 | HIGH | Global and per-endpoint rate limits, 429 + Retry-After. Real client IP behind proxies (`trust proxy`). Body size limit, pagination cap, timeouts. |
| **F. Files** |||
| B27 | BLOCKER | Uploads: size limit, extension allowlist and magic-byte check. Random file names. Stored outside the web root or in private storage, served via signed URLs. HTML/SVG blocked or served as `attachment`. |
| **G. Secrets** |||
| B28 | BLOCKER | Secrets in `.env` (gitignored, with `.env.example`) or a secret manager. No secrets in git history. Leaked secrets rotated. Separate secrets per environment, least privilege. |
| **H. Errors and logging** |||
| B29 | BLOCKER | Global exception handler: generic message plus correlation id, no stack trace. Async errors are caught and cannot crash the process. |
| B30 | BLOCKER | Production config: debug off, Swagger off or protected, no default credentials. |
| B31 | HIGH | Audit log for auth events, role changes and admin actions. No passwords, tokens or PII in logs. Logs centralized with alerting. |
| **I. Database** |||
| B32 | BLOCKER | DB not reachable from the public internet. The app connects with a least-privilege user (no superuser, no default password) over TLS. |
| B33 | BLOCKER | With a BaaS (Supabase/Firebase): RLS/Rules on every table, default deny, negative-tested with the anon key. No service_role key on the client. |
| B34 | MEDIUM | Sensitive fields encrypted. Versioned migrations. |
| **J. Backup** |||
| B35 | BLOCKER | Backups automatic, encrypted, in a separate account/region. Restore tested. RPO/RTO defined. |
| **K. Supply chain and CI** |||
| B36 | HIGH | Dependency scanning in place. No critical CVEs. Lockfile committed. |
| B37 | HIGH | CI runs SAST, secret scanning and container/IaC scanning; critical findings fail the build. Branch protection on. |
| **L. Operations and privacy** |||
| B38 | HIGH | Health endpoint leaks nothing. Monitoring, alerting and uptime checks in place. |
| B39 | HIGH | Privacy law compliance (GDPR, KVKK, etc.): data minimization, deletion/export flows, retention periods, consent records, legal basis for cross-border transfers, DPAs with processors. |

## Common mistakes
| Mistake | Reality |
|---|---|
| "The token is in a header, no cookies, so no CSRF, all good" | ➖ for CSRF is right. But the token lives in JS, so B02 is ❌: XSS = account takeover. |
| "IDs are UUIDs, so no IDOR" | UUIDs leak through logs, URLs and referers. B11 requires an ownership filter in the query. |
| "The admin panel is IP-locked, that's enough" | An IP lock is an extra layer. B09, B12 and B14 are still required. |
| "We use helmet, so headers are done" | Helmet's default CSP is usually fine for an API, but CORS and cookie settings are checked separately. |
| Giving ✅ to an item you cannot see in code | That item is ❓. Backups, MFA and DB network access are not visible in code. |
| Recommending "delete it from the file" for a leaked secret | Rotate first. It may still be in git history or copies. |
