# Node.js (Express / NestJS / Next.js route handlers) implementation notes

## B01 Passwords
```js
import argon2 from 'argon2';
const hash = await argon2.hash(password, { type: argon2.argon2id });
const ok = await argon2.verify(user.passwordHash, password);
```
- When the user is not found, still call `argon2.verify` against a dummy hash so the response time does not reveal whether the user exists (B07).
- Put a maximum length on passwords (e.g. `z.string().max(1024)`). A megabyte-sized password keeps argon2 busy and becomes a CPU DoS.

## B02/B03/B25 Cookies + short-lived tokens + refresh rotation
```js
res.cookie('__Host-session', accessToken, { httpOnly: true, secure: true, sameSite: 'lax', path: '/', maxAge: 15 * 60_000 });
// __Host- requires Path=/, so a path-scoped refresh cookie uses __Secure- instead.
// Use Path=/auth: scoping it to /auth/refresh means /auth/logout never receives it and cannot revoke it.
res.cookie('__Secure-refresh', refreshToken, { httpOnly: true, secure: true, sameSite: 'strict', path: '/auth', maxAge: 30 * 864e5 });
```
- Generate refresh tokens with `crypto.randomBytes(32).toString('base64url')` and store `sha256(token)` in the DB. SHA-256 is fine here because the token has high entropy; it is not fine for passwords.
- The `/auth/refresh` steps must run in **one transaction**:
  1. Conditionally update the row: `UPDATE ... SET used_at=now() WHERE token_hash=$1 AND used_at IS NULL AND expires_at>now() RETURNING ...`
  2. If no row comes back, this is either reuse or expiry. Delete every token in that family and return 401.
  3. If a row comes back, issue a new token pair with the same `family_id` and the same absolute `expires_at`.
  4. Commit. Set the cookies only after the commit succeeds.
- If two tabs refresh at the same moment, the second counts as reuse and the user is logged out. Either accept this or allow a grace window of a few seconds, and document which you chose.
- Schedule a periodic `DELETE ... WHERE expires_at < now()` job for expired rows.
- On logout (B04), delete the family of the token in the cookie and clear the cookies. On password change, delete all of the user's families.

## B05 JWT
```js
jwt.sign(payload, key, { algorithm: 'HS256', expiresIn: '15m', issuer: ISS, audience: AUD });
jwt.verify(token, key, { algorithms: ['HS256'], issuer: ISS, audience: AUD });
```
`key` must be generated with `crypto.randomBytes(32)` and read from env. `jsonwebtoken` versions below 9 have known CVEs; upgrade.

## B06/B26 Rate limits + resource caps
```js
import { rateLimit } from 'express-rate-limit';
app.set('trust proxy', 1);                        // exactly the number of proxies in front of the app
app.use(express.json({ limit: '100kb' }));
app.use(rateLimit({ windowMs: 60_000, limit: 100, standardHeaders: 'draft-7', legacyHeaders: false }));
const loginIp = rateLimit({ windowMs: 15 * 60_000, limit: 20 });
const loginAccount = rateLimit({ windowMs: 15 * 60_000, limit: 5, skipSuccessfulRequests: true,   // count failures only
  keyGenerator: (req) => 'acct:' + String(req.body?.email ?? '').trim().toLowerCase() });
app.post('/auth/login', loginIp, loginAccount, login);
```
With more than one instance, back the limiter with a Redis store (`rate-limit-redis`).

## B10/B11/B12 Deny by default + ownership
```js
app.use('/api', requireAuth);                     // public routes are defined BEFORE this line
app.get('/api/orders/:id', async (req, res) => {
  const { rows } = await db.query('SELECT * FROM orders WHERE id = $1 AND user_id = $2', [req.params.id, req.user.id]);
  if (!rows[0]) return res.sendStatus(404);
  res.json(toDto(rows[0]));
});
```
`req.user` is populated only from the verified session or token. Values such as `req.headers['x-role']` are never used.
In NestJS, use a global `APP_GUARD` plus a `@Public()` decorator.

## B13/B15 Validation + allowlists
```js
const UpdateProfile = z.object({ displayName: z.string().min(1).max(80), bio: z.string().max(500).optional() }).strict();
const parsed = UpdateProfile.safeParse(req.body);
if (!parsed.success) return res.status(400).json({ error: 'Invalid input' });
```
In NestJS, use `new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true })`.

## B16 SQL
- Use an allowlist for dynamic columns or sorting:
  ```js
  const SORTS = { created: 'created_at', total: 'total' };
  const col = SORTS[req.query.sort] ?? 'created_at';
  ```
  Values are always passed as parameters such as `$1`, `$2`.
- In Prisma, `$queryRaw` as a tagged template is safe; `$queryRawUnsafe` is not.

## B18 SSRF
- Allow only the `https:` scheme in user-supplied URLs.
- Resolve the host via DNS. Reject the request unless `ipaddr.parse(ip).range() === 'unicast'` (`ipaddr.js`). This covers private, loopback, link-local and 169.254.169.254.
- The IP you validated must be the IP you connect to (DNS rebinding). Do the check in the HTTP agent's `lookup` function.
- Use `redirect: 'manual'`.
- Keep the endpoint behind auth and a rate limit.

## B21 CSRF (cookie auth)
`csurf` is deprecated. Use one of these instead:
- `csrf-csrf` (double-submit)
- An Origin check together with SameSite cookies:
```js
app.use((req, res, next) => {
  if (['GET', 'HEAD', 'OPTIONS'].includes(req.method)) return next();
  if (!ALLOWED_ORIGINS.includes(req.get('origin'))) return res.sendStatus(403);
  next();
});
```
This also rejects clients that send no Origin header (server-to-server calls, curl). Apply it only to browser-facing APIs and give other clients a separate auth path (e.g. API keys as Bearer).

## B22/B24 CORS + headers
```js
app.use(helmet());                                // nosniff, frameguard, HSTS, removes x-powered-by, etc.
app.use(cors({ origin: process.env.CORS_ORIGINS.split(','), credentials: true }));
```
`origin: true` reflects the incoming origin back. Combined with credentials, that is ❌.

## B27 Upload (multer)
```js
const ALLOWED = { 'image/png': '.png', 'image/jpeg': '.jpg', 'image/webp': '.webp' };
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 5 * 1024 * 1024, files: 1 } });
// handler:
const type = await fileTypeFromBuffer(req.file.buffer);           // 'file-type' package (ESM), magic bytes
if (!type || !ALLOWED[type.mime]) return res.status(400).json({ error: 'Unsupported file' });
const key = crypto.randomUUID() + ALLOWED[type.mime];             // originalname is never used in a path
// re-encode with sharp → put in a private bucket → return a signed URL
```
multer versions before 2.x have DoS CVEs.

## B29 Error handling
- Express 4 does not catch async errors. Either move to Express 5 or wrap every handler with `wrap(fn)`.
```js
app.use((err, req, res, next) => {
  const id = crypto.randomUUID();
  logger.error({ err, id, path: req.path });
  res.status(500).json({ error: 'Unexpected error', correlationId: id });
});
process.on('unhandledRejection', (e) => logger.fatal(e));        // log it; let the supervisor restart the process
```

## B28/B30/B36/B38
- Add `.env` to `.gitignore` and keep a `.env.example` in the repo. In production, read secrets from the platform env or a secret manager.
- Set `NODE_ENV=production` in production.
- Run `npm audit --omit=dev` for dependency vulnerabilities and commit the lockfile.
- The health endpoint returns only the status: `app.get('/health', (req, res) => res.json({ status: 'ok' }))`. Never env, versions or connection strings.

## Next.js route handlers / server actions
- Every handler and server action does its own auth and ownership check. Middleware/proxy alone is not a security boundary; the CVE-2025-29927 middleware bypass is an example.
- Validate input with zod.
- Write cookies with `(await cookies()).set(name, value, { httpOnly: true, secure: true, sameSite: 'lax' })`. `cookies()` is async from Next 15 on.
- Never keep secrets in `NEXT_PUBLIC_` variables.
