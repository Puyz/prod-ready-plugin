# Backend checklist — details

Each item has this structure:
- **Why:** the rationale
- **Verify:** what to look at and which patterns to search for
- **Pass:** acceptance criteria
- **Pitfall:** a common mistake

Grep patterns are only a starting point. Read every match; the absence of a match is not evidence.

---

## A. Authentication

### B01 — Password hashing (BLOCKER)
- **Why:** if the DB leaks, fast hashes (MD5, SHA*) are cracked within minutes.
- **Verify:**
  - Search for `md5|sha1|sha256|createHash|SHA256.Create|HashPassword|bcrypt|argon2|scrypt|pbkdf2`.
  - Follow how the password field gets written.
- **Pass:** Argon2id (m≥19MiB, t≥2) or bcrypt (cost≥10), or PBKDF2 at OWASP iteration counts. A unique salt per password (libraries do this automatically). Old hashes are rehashed on login.
- **Pitfall:** "SHA256 + salt" is not enough either. Never write the hashing yourself; use a library.

### B02 — Token storage (BLOCKER)
- **Why:** any XSS can read a token in localStorage. An httpOnly cookie cannot be read from JS.
- **Verify:**
  - Find the login response: is there something like `res.json({ token` or `return Ok(new { token`?
  - Check `httpOnly`, `secure` and `sameSite` on `Set-Cookie`/`res.cookie`/`AppendCookie`.
  - Does the frontend call `localStorage.setItem`?
- **Pass:** the session or token travels in a cookie flagged `HttpOnly; Secure; SameSite=Lax|Strict`. The refresh cookie uses the `__Secure-` prefix and is scoped to `Path=/auth`. (`__Host-` requires Path=/. Scoping to `/auth/refresh` would stop logout from receiving the cookie.) SPAs use a BFF: the token stays on the server and the browser only holds a session cookie.
- **Pitfall:** Bearer tokens are acceptable for mobile apps or third-party API clients. In that case score the item for the web client.

### B03 — Token lifetime and refresh rotation (BLOCKER)
- **Why:** a stolen token should become useless quickly, and a stolen refresh token should be caught on its first reuse.
- **Verify:**
  - Check the values of `expiresIn|exp|ExpireTimeSpan|AccessTokenLifetime`.
  - Does the refresh endpoint invalidate the old token and issue a new one?
  - When the same refresh token is used twice, is the whole token family revoked?
- **Pass:** access token lives 5–15 min. Refresh tokens are single-use, rotated and stored hashed. There is an absolute lifetime (e.g. 30 days) that rotation does not extend. Rotation runs in one transaction and the cookie is set only after commit.
- **Pitfall:** a JWT without an expiry is valid forever.

### B04 — Server-side revocation (BLOCKER)
- **Verify:**
  - Does logout only clear the cookie, or does it also delete the session/refresh record?
  - Are other sessions dropped after a password change or reset?
- **Pass:** logout, password change and "sign out everywhere" delete server-side records. Access tokens rely on a short lifetime or a denylist.

### B05 — JWT validation (BLOCKER)
- **Verify:**
  - Is the `algorithms` option passed to `jwt.verify(token, secret)`?
  - Are `ValidateIssuer/Audience/Lifetime/IssuerSigningKey` true?
  - What is the secret? `secret`, `changeme` or anything shorter than 32 bytes means ❌.
- **Pass:** algorithm pinned; iss, aud and exp validated; a random secret ≥256 bits, or an RS256/EdDSA key pair.
- **Pitfall:** `jwt.decode` only decodes the token; it does not verify the signature.

### B06 — Brute-force protection (BLOCKER)
- **Verify:**
  - Are there rate limiters on login, register, forgot-password, OTP and verify endpoints?
  - Is the limit applied per account (email), not only per IP?
- **Pass:** a per-IP limit (e.g. 10/min) and a per-account limit (e.g. after 5 failures, increasing delay or a 15-minute lock).
- **Pitfall:** a permanent account lock hands attackers a DoS. Locks must expire.

### B07 — User enumeration (HIGH)
- **Verify:**
  - Compare login, register and forgot-password responses: do messages or status codes differ?
  - Does the code return early without hashing when the user is not found (timing difference)?
- **Pass:**
  - One identical response in every case: "Invalid email or password".
  - Forgot-password always says "If the account exists, an email has been sent".
  - A dummy hash is computed when the user does not exist (timing difference closed).

### B08 — Password reset (HIGH)
- **Pass:** token is ≥128 random bits, stored hashed, single-use and valid for 30–60 minutes at most. Using it revokes other sessions. If the token is in the URL, the page sends `Referrer-Policy: no-referrer`.

### B09 — MFA (HIGH)
- **Verify:** is TOTP or WebAuthn required for admin and privileged roles? If an IdP handles admin login, is MFA enforced there? If not visible in code, ❓.

## B. Authorization

### B10 — Deny by default (BLOCKER)
- **Verify:**
  - List all routes.
  - Is auth middleware global or added per route?
  - Review every `[AllowAnonymous]`/public route.
- **Pass:** auth is applied globally and public routes are explicitly marked, or every route has auth and none is missing.

### B11 — IDOR / ownership (BLOCKER)
- **Why:** "does this request belong to this person?" This is the most common and most damaging gap.
- **Verify:**
  - Find every endpoint taking `:id`, `{id}` or `?id=`.
  - Does the query filter by `user_id = currentUser` or `tenant_id`?
  - If the code fetches the record first and checks the owner afterwards, confirm the check really happens.
- **Pass:** the ownership filter is inside the query on every endpoint. Requests for someone else's resource return 404.
- **Pitfall:** the list endpoint is filtered but the detail endpoint is not. Check update, delete and export endpoints separately too.

### B12 — Source of identity and role (BLOCKER)
- **Verify:** search for things like `req.headers['x-role'|'x-user-id']`, `body.userId`, `body.role`, `query.isAdmin`.
- **Pass:** identity and role come only from the verified session or token claims. Role changes take effect immediately: critical actions read the role from the DB.

### B13 — Mass assignment (HIGH)
- **Verify:** search for `Object.assign(entity, req.body)`, `...req.body`, `update(req.body)`, SQL column names built from body keys, or entities bound directly by model binding.
- **Pass:** every endpoint has its own DTO or allowlist. Sensitive fields can only be changed through separate, authorized endpoints.

### B14 — Admin panel (HIGH)
- **Pass:**
  - An admin role exists and is checked server-side.
  - MFA required (B09).
  - Admin actions are written to the audit log (B31).
  - IP allowlist, VPN or Zero Trust (Cloudflare Access etc.) as an extra layer.
  - The admin panel is on its own subdomain and not listed in `robots.txt`.

## C. Input and injection

### B15 — Server-side validation (BLOCKER)
- **Verify:** is a schema library used for body, query and params (zod/joi/class-validator/FluentValidation/DataAnnotations)? Which endpoints have no validator?
- **Pass:** every endpoint checks type, length and format; enums pass an allowlist; unknown fields are rejected or ignored. Every string field, passwords included, has a maximum length; an unbounded password exposes argon2 to CPU DoS.

### B16 — SQL injection (BLOCKER)
- **Verify:** do `query(` / `execute(` / `FromSqlRaw` / `ExecuteSqlRaw` / `$queryRawUnsafe` / `.raw(` calls use `+`, template strings `${` or `string.Format`? Where do dynamic ORDER BY, column or table names come from?
- **Pass:** all values are passed as parameters. Identifiers (columns, tables, sort keys) are picked from a fixed allowlist.
- **Pitfall:** `FromSql`/`FromSqlInterpolated` are safe; `FromSqlRaw($"...")` is not.

### B17 — Other injection (HIGH)
- **Verify:** search for `exec|spawn|child_process|Process.Start|eval|new Function`, path joins (`path.join(base, userInput)`), request bodies passed straight into Mongo queries (`{$ne:..}`), templates compiled from user input.
- **Pass:** no shell calls, or arguments passed as an array and allowlisted. Paths are normalized and checked to stay inside the base directory.

### B18 — SSRF (HIGH)
- **Verify:** do `fetch|axios|HttpClient|request|got` calls use a URL that comes from the user (webhooks, previews, imports, avatar URLs)?
- **Pass:**
  - A host allowlist, or the resolved IP is checked against private, loopback and link-local ranges (169.254.169.254 included).
  - Redirects disabled, or every redirect re-validated.
  - The endpoint is behind auth.
  - The response is not reflected to the user as-is.

### B19 — Deserialization (HIGH)
- **Verify:** search for `TypeNameHandling` (≠ None), `BinaryFormatter`, `pickle.loads`, unsafe `yaml.load`, `node-serialize`.

### B20 — Backend XSS (HIGH)
- **Verify:**
  - Is user HTML stored or served? Is there a server-side sanitizer (sanitize-html, HtmlSanitizer)?
  - Does `res.send(userContent)` return `text/html`?
  - Are there raw outputs in templates (`<%-`, `@Html.Raw`, `{{{ }}}`)?
- **Pass:** the API returns JSON. HTML either passes an allowlist sanitizer or is not accepted at all.

## D. Browser and transport

### B21 — CSRF (BLOCKER, only with cookie auth)
- **Pass:** cookies are `SameSite=Lax` or `Strict`. State-changing requests require a CSRF token (synchronizer or double-submit) or a custom header plus an Origin check. GET requests have no side effects.
- **When ➖:** auth uses only the `Authorization` header. Add a note pointing to B02.

### B22 — CORS (BLOCKER)
- **Verify:** look at `cors(` / `AddCors` / `Access-Control-Allow-Origin`. Is there `origin: true`, `'*'` or `SetIsOriginAllowed(_ => true)`? Is any of them combined with `credentials`?
- **Pass:** production domains listed explicitly, origins read from env, the incoming origin never reflected as-is.

### B23 — HTTPS (BLOCKER)
- **Verify:**
  - Search for production URLs starting with `http://`.
  - Is there redirect middleware (`UseHttpsRedirection`, proxy config)?
  - Is HSTS set?
  - Do service-to-service and DB connections use TLS?
- **Pass:** traffic encrypted with TLS 1.2+. HTTP redirected to HTTPS with 301 (for browser-facing apps; pure APIs should not listen on HTTP at all). `Strict-Transport-Security: max-age=31536000; includeSubDomains`. Add preload only later.

### B24 — Security headers (HIGH)
- **Pass:**
  - `X-Content-Type-Options: nosniff`
  - `frame-ancestors 'none'` or `X-Frame-Options: DENY`
  - `Referrer-Policy: strict-origin-when-cross-origin`
  - `Permissions-Policy`
  - CSP when HTML is served
  - `X-Powered-By` and version-revealing `Server` headers removed
- **Verify:** are these headers really returned in production? Check with `curl -sI https://<host>` if a live environment exists.

### B25 — Cookie flags (HIGH)
- **Pass:**
  - Session cookie uses the `__Host-` prefix, which enforces Secure, Path=/ and no Domain. Path-scoped cookies (e.g. refresh) are acceptable with `__Secure-`.
  - `HttpOnly`, `Secure` and `SameSite` set.
  - Max-Age consistent with the session lifetime.

## E. Abuse

### B26 — Rate limits and resource caps (HIGH)
- **Verify:**
  - Is there a global limiter? Separate limits on expensive endpoints (search, export, AI calls, email sending)?
  - Is the real client IP used behind a proxy or load balancer (`trust proxy`, `ForwardedHeaders`)?
  - Does the body parser have a limit?
  - Is there a cap on `limit`/`pageSize`?
  - Do DB and HTTP calls have timeouts?
- **Pass:** all of the above, with 429 and `Retry-After` when a limit is hit.
- **Pitfall:** a wrong `trust proxy` setting causes one of two problems: every request appears to come from one IP, or `X-Forwarded-For` can be spoofed to bypass the limit.

## F. File upload

### B27 — Upload (BLOCKER)
- **Verify:** look at multer, IFormFile, busboy and S3 putObject usage.
- **Pass:**
  1. Size limit.
  2. Extension allowlist and magic-byte check. Looking only at the `Content-Type` header is not enough.
  3. File name generated server-side (UUID). `originalname` never used in a path.
  4. Files kept outside the web root or in a private bucket and served via short-lived signed URLs.
  5. Images re-encoded and EXIF stripped.
  6. SVG and HTML rejected, or served with `Content-Disposition: attachment` and `nosniff`.
  7. Per-user upload quota.
  8. Malware scanning (recommended).

## G. Secrets

### B28 — Secrets (BLOCKER)
- **Verify:**
  - Does `.gitignore` include `.env*` (except `!.env.example`)?
  - Search the repo for `sk_live|sk-|AKIA|-----BEGIN|password=|ConnectionStrings`.
  - Any secrets in `appsettings.json`?
  - If git exists, scan history with `gitleaks detect`.
- **No git:** history scanning is ❓. A non-ignored `.env` file is still a reason for ❌.
- **Pass:** production secrets in a secret manager (Vault, AWS SM, Azure Key Vault, Doppler) or the platform's env settings. Only `.env.example` in the repo. Separate secrets per environment. Keys with least privilege (e.g. Stripe restricted keys).
- **If leaked:** the first step is to **rotate**. Deleting it from the file or history is not enough on its own.

## H. Errors and logging

### B29 — Exception handling (BLOCKER)
- **Verify:**
  - Does the global handler's response include `err.stack`, `err.message` or `ex.ToString()`?
  - In Express 4, are errors in async routes caught? Otherwise an unhandled rejection can crash the process. (Express 5 catches them itself.)
  - Is there `process.on('unhandledRejection')` or another logging strategy?
- **Pass:** the user gets `{ error: "Unexpected error", correlationId }`. Details go to the server log. A single bad request cannot take the process down.

### B30 — Production config (BLOCKER)
- **Verify:**
  - Check `NODE_ENV`/`ASPNETCORE_ENVIRONMENT`.
  - Are `UseDeveloperExceptionPage`, Swagger/OpenAPI UI or GraphQL introspection enabled in production?
  - Do seeds contain default users such as admin/admin?
  - Are there debug endpoints (`/debug`, `/test`, `/env`)?
- **Pass:** all off, or behind auth.

### B31 — Audit log (HIGH)
- **Pass:**
  - These events are written as structured logs with `who/what/when/ip/result`: login success and failure, password change and reset, MFA changes, role changes, admin actions, data exports.
  - No passwords, tokens, card numbers or national ID numbers in logs (masked or redacted).
  - Logs collected centrally in append-only storage with a defined retention.
  - Anomalies raise alerts (e.g. a spike in failed logins).

## I. Database

### B32 — DB access (BLOCKER)
- **Verify:**
  - Check the user in the connection string: `postgres`, `sa`, `root` → ❌.
  - Check the password: a default value → ❌.
  - Check the host: if public → ❓ (ask about network rules).
  - Check `sslmode`/`Encrypt=true`.
- **Pass:** the DB is on a private network (SG/firewall allows only the app). The app user has DML rights only. Migrations run under a separate user. Connections use TLS.

### B33 — BaaS rules (BLOCKER)
- **Why:** with Supabase or Firebase the browser talks to the DB directly. Without rules, anyone can read and write everything.
- **Verify:**
  - Supabase: does every table have `alter table ... enable row level security`? Are policies scoped with `auth.uid()`? Is the `service_role` key anywhere in client code?
  - Firebase: do `firestore.rules`/`storage.rules` contain `allow read, write: if true` or a date-based test rule?
- **Pass:** RLS on every table with default deny. A negative test with the anon key cannot read another user's data.
- **When ➖:** the browser never accesses the DB directly.

### B34 — Encryption and migrations (MEDIUM)
- **Pass:** disk/at-rest encryption on. Sensitive fields such as national IDs, health and financial data encrypted at the application level. Schema changes go through versioned migrations.

## J. Backup

### B35 — Backup and restore (BLOCKER, usually ❓)
- **Pass:**
  - Backups automatic (PITR preferred) and encrypted.
  - Backups in a different account or region, protected against deletion (immutable or object lock).
  - Retention defined.
  - **A restore test within the last 3 months**, with the duration measured.
  - RPO and RTO written down.
- **Note:** usually not visible in code. Mark ❓ and ask the owner "when was the last restore test?"

## K. Supply chain and CI

### B36 — Dependencies (HIGH)
- **Verify:** run `npm audit --omit=dev`, `dotnet list package --vulnerable --include-transitive` or `pip-audit` (if network access exists). Is there a lockfile? A Dependabot or Renovate config?
- **Pass:** no unresolved critical or high CVEs. Lockfile committed. Automated updates enabled.
- **Note:** if the command could not run, estimate from versions, mark ⚠️ and say "not verified".

### B37 — CI security (HIGH)
- **Verify:** look at `.github/workflows`, `.gitlab-ci.yml`, `azure-pipelines.yml`:
  - CodeQL or Semgrep?
  - gitleaks or trufflehog?
  - Trivy or Grype?
  - IaC scanning (checkov/tfsec)?
  - Do findings fail the build?
- **Pass:** the scans above exist and critical findings fail the build. Main branch protected, PR review required. CI secrets scoped per environment with least privilege. No unsafe checkout with `pull_request_target`.

## L. Operations and privacy

### B38 — Health and monitoring (HIGH)
- **Verify:** does the health endpoint return config, env, versions or connection strings? Are there uptime and error-rate alerts?
- **Pass:** health returns only `{status:"ok"}`. Detailed health only on the internal network or behind auth. Uptime monitor plus error-rate and latency alerts, each with an owner.

### B39 — Privacy compliance (HIGH)
- **Pass (jurisdiction-agnostic core):**
  - Only the data that is needed is collected.
  - Users' data can be deleted and exported. Deletion is consistent with the backup and log policy.
  - Retention periods are defined and expired data is deleted automatically.
  - When consent is collected, the time, the text version and the source are recorded.
  - Cross-border transfers (Google, Stripe, OpenAI, cloud providers, etc.) have a legal basis.
  - Data processing agreements (DPAs) are signed with processors.
- **Jurisdiction specifics:** identify the target markets (user statement, locales, currencies, legal pages). For the details of each market, read the matching file from the `prod-ready-frontend` skill: `../prod-ready-frontend/references/privacy-eu.md` (GDPR) and `../prod-ready-frontend/references/privacy-tr.md` (KVKK). Their "Backend" sections apply to B39.
- **Note:** legal adequacy is ❓. On the code side, look for deletion/export endpoints, retention jobs and consent records.
