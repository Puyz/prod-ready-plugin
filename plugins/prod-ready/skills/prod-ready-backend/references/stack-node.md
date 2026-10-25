# Node.js (Express / NestJS / Next.js route handlers) uygulama notları

## B01 Parola
```js
import argon2 from 'argon2';
const hash = await argon2.hash(password, { type: argon2.argon2id });
const ok = await argon2.verify(user.passwordHash, password);
```
- Kullanıcı bulunamadığında da sahte bir `argon2.verify` çağır, böylece yanıt süresi kullanıcının var olup olmadığını ele vermez (B07).
- Parolaya üst uzunluk sınırı koy (ör. `z.string().max(1024)`). Megabaytlık bir parola girdisi argon2'yi meşgul ederek CPU DoS'a yol açar.

## B02/B03/B25 Cookie + kısa ömürlü token + refresh rotation
```js
res.cookie('__Host-session', accessToken, { httpOnly: true, secure: true, sameSite: 'lax', path: '/', maxAge: 15 * 60_000 });
// __Host- öneki Path=/ ister; path daraltılmış refresh cookie'si bu yüzden __Secure- ile başlar.
// Path=/auth kullan: /auth/refresh'e daraltırsan /auth/logout cookie'yi alamaz ve iptal edemez.
res.cookie('__Secure-refresh', refreshToken, { httpOnly: true, secure: true, sameSite: 'strict', path: '/auth', maxAge: 30 * 864e5 });
```
- Refresh token'ı `crypto.randomBytes(32).toString('base64url')` ile üret. DB'de `sha256(token)` sakla. Token yüksek entropili olduğu için SHA-256 burada yeterli; parola için yeterli değil.
- `/auth/refresh` adımları **tek transaction** içinde çalışmalı:
  1. Kaydı koşullu güncelle: `UPDATE ... SET used_at=now() WHERE token_hash=$1 AND used_at IS NULL AND expires_at>now() RETURNING ...`
  2. Hiç satır dönmezse ya reuse ya da süre dolması vardır. O ailenin tüm token'larını sil ve 401 dön.
  3. Satır dönerse aynı `family_id` ve aynı mutlak `expires_at` ile yeni token çiftini üret.
  4. Commit et. Cookie'leri yalnızca commit başarılı olduktan sonra set et.
- İki sekme aynı anda refresh yaparsa ikincisi reuse sayılır ve kullanıcı çıkış yapmış olur. Bu davranış ya kabul edilir ya da birkaç saniyelik bir tolerans penceresi tanımlanır. Hangisini seçtiğini dokümante et.
- Süresi dolmuş satırlar için periyodik `DELETE ... WHERE expires_at < now()` job'u kur.
- Logout'ta (B04) cookie'deki token'ın ailesini sil ve cookie'leri temizle. Parola değişince kullanıcının tüm ailelerini sil.

## B05 JWT
```js
jwt.sign(payload, key, { algorithm: 'HS256', expiresIn: '15m', issuer: ISS, audience: AUD });
jwt.verify(token, key, { algorithms: ['HS256'], issuer: ISS, audience: AUD });
```
`key` için `crypto.randomBytes(32)` ile üretilip env'den okunan bir değer kullanılmalı. Varsa bir `jsonwebtoken@<9` sürümü bilinen CVE'lere sahiptir, güncelle.

## B06/B26 Rate limit + kaynak sınırları
```js
import { rateLimit } from 'express-rate-limit';
app.set('trust proxy', 1);                        // tam olarak önündeki proxy sayısı kadar
app.use(express.json({ limit: '100kb' }));
app.use(rateLimit({ windowMs: 60_000, limit: 100, standardHeaders: 'draft-7', legacyHeaders: false }));
const loginIp = rateLimit({ windowMs: 15 * 60_000, limit: 20 });
const loginAccount = rateLimit({ windowMs: 15 * 60_000, limit: 5, skipSuccessfulRequests: true,   // yalnızca başarısızları say
  keyGenerator: (req) => 'acct:' + String(req.body?.email ?? '').trim().toLowerCase() });
app.post('/auth/login', loginIp, loginAccount, login);
```
Birden fazla instance çalışıyorsa limiter'a Redis store bağla (`rate-limit-redis`).

## B10/B11/B12 Varsayılan deny + sahiplik
```js
app.use('/api', requireAuth);                     // public route'lar bu satırdan ÖNCE tanımlanır
app.get('/api/orders/:id', async (req, res) => {
  const { rows } = await db.query('SELECT * FROM orders WHERE id = $1 AND user_id = $2', [req.params.id, req.user.id]);
  if (!rows[0]) return res.sendStatus(404);
  res.json(toDto(rows[0]));
});
```
`req.user` yalnızca doğrulanmış session veya token'dan doldurulur. `req.headers['x-role']` gibi değerler asla kullanılmaz.
NestJS'te global `APP_GUARD` + `@Public()` decorator deseni kullanılır.

## B13/B15 Validation + allowlist
```js
const UpdateProfile = z.object({ displayName: z.string().min(1).max(80), bio: z.string().max(500).optional() }).strict();
const parsed = UpdateProfile.safeParse(req.body);
if (!parsed.success) return res.status(400).json({ error: 'Geçersiz veri' });
```
NestJS'te `new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true })` kullan.

## B16 SQL
- Dinamik kolon veya sıralama için allowlist kullan:
  ```js
  const SORTS = { created: 'created_at', total: 'total' };
  const col = SORTS[req.query.sort] ?? 'created_at';
  ```
  Değerler her zaman `$1`, `$2` gibi parametrelerle verilir.
- Prisma'da `$queryRaw` tagged template olarak güvenlidir, `$queryRawUnsafe` ise güvensizdir.

## B18 SSRF
- Kullanıcının verdiği URL'de yalnızca `https:` şemasına izin ver.
- Host'u DNS ile çöz. `ipaddr.js` ile `ipaddr.parse(ip).range() === 'unicast'` değilse isteği reddet. Bu kontrol private, loopback, link-local ve 169.254.169.254'ü kapsar.
- Doğrulanan IP ile bağlanılan IP aynı olmalı (DNS rebinding'e karşı). Bunun için kontrolü HTTP agent'ın `lookup` fonksiyonunda yap.
- `redirect: 'manual'` kullan.
- Endpoint auth ve rate limit arkasında olmalı.

## B21 CSRF (cookie auth)
`csurf` paketi deprecated. Yerine şunlardan birini kullan:
- `csrf-csrf` (double-submit)
- SameSite cookie ile birlikte Origin kontrolü:
```js
app.use((req, res, next) => {
  if (['GET', 'HEAD', 'OPTIONS'].includes(req.method)) return next();
  if (!ALLOWED_ORIGINS.includes(req.get('origin'))) return res.sendStatus(403);
  next();
});
```
Bu kontrol Origin header'ı göndermeyen istemcileri de reddeder (server-to-server çağrılar, curl). Yalnızca tarayıcının kullandığı API'lerde uygula. Diğer istemciler için ayrı bir auth yolu tanımla (ör. API key ile Bearer).

## B22/B24 CORS + headers
```js
app.use(helmet());                                // nosniff, frameguard, HSTS, x-powered-by kaldırma vb.
app.use(cors({ origin: process.env.CORS_ORIGINS.split(','), credentials: true }));
```
`origin: true` gelen origin'i aynen geri yansıtır. Bu, credentials ile birlikte kullanıldığında ❌'dir.

## B27 Upload (multer)
```js
const ALLOWED = { 'image/png': '.png', 'image/jpeg': '.jpg', 'image/webp': '.webp' };
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 5 * 1024 * 1024, files: 1 } });
// handler:
const type = await fileTypeFromBuffer(req.file.buffer);           // 'file-type' paketi (ESM), magic bytes
if (!type || !ALLOWED[type.mime]) return res.status(400).json({ error: 'Desteklenmeyen dosya' });
const key = crypto.randomUUID() + ALLOWED[type.mime];             // originalname dosya yolunda kullanılmaz
// sharp ile re-encode → private bucket'a koy → signed URL dön
```
multer'ın 2.x öncesi sürümlerinde DoS CVE'leri var.

## B29 Hata yönetimi
- Express 4 async hataları yakalamaz. Ya Express 5'e geç ya da her handler'ı `wrap(fn)` ile sarmala.
```js
app.use((err, req, res, next) => {
  const id = crypto.randomUUID();
  logger.error({ err, id, path: req.path });
  res.status(500).json({ error: 'Beklenmeyen bir hata oluştu', correlationId: id });
});
process.on('unhandledRejection', (e) => logger.fatal(e));        // log'la; supervisor process'i yeniden başlatsın
```

## B28/B30/B36/B38
- `.env` içeriği `.gitignore`'a eklenmeli ve repoda `.env.example` bulunmalı. Prod'da secret'lar platform env'inden veya secret manager'dan okunmalı.
- Prod'da `NODE_ENV=production` set edilmeli.
- Bağımlılık açıkları için `npm audit --omit=dev` çalıştırılmalı ve lockfile commit edilmeli.
- Health endpoint'i yalnızca durum dönmeli: `app.get('/health', (req, res) => res.json({ status: 'ok' }))`. Env, versiyon ve connection string döndürülmemeli.

## Next.js route handlers / server actions
- Her handler ve server action kendi auth ve sahiplik kontrolünü yapmalı. Middleware tek başına güvenlik sınırı değildir; CVE-2025-29927 middleware bypass'ı buna örnektir.
- Girdiler zod ile doğrulanmalı.
- Cookie'ler `(await cookies()).set(name, value, { httpOnly: true, secure: true, sameSite: 'lax' })` ile yazılmalı. Next 15 ve sonrasında `cookies()` async'tir.
- Secret'lar `NEXT_PUBLIC_` önekli değişkenlerde tutulmamalı.
