# Backend checklist — detaylar

Her madde şu yapıdadır:
- **Neden:** maddenin gerekçesi
- **Doğrula:** neye bakılacağı ve hangi desenlerin aranacağı
- **Geçer:** kabul kriteri
- **Tuzak:** sık yapılan hata

Grep desenleri yalnızca başlangıç noktasıdır. Eşleşen her yeri oku; eşleşmenin olmaması da kanıt sayılmaz.

---

## A. Kimlik doğrulama

### B01 — Parola hash (BLOCKER)
- **Neden:** DB sızarsa hızlı hash'ler (MD5, SHA*) dakikalar içinde kırılır.
- **Doğrula:**
  - `md5|sha1|sha256|createHash|SHA256.Create|HashPassword|bcrypt|argon2|scrypt|pbkdf2` desenlerini ara.
  - Parola alanının nasıl yazıldığını takip et.
- **Geçer:** Argon2id (m≥19MiB, t≥2) veya bcrypt (cost≥10) kullanılıyor. Her parola için ayrı salt var (kütüphane bunu otomatik yapar). Eski hash'ler login sırasında rehash ediliyor.
- **Tuzak:** "SHA256 + salt" da yetersizdir. Hash'leme işini kendin yazma, kütüphaneye bırak.

### B02 — Token saklama (BLOCKER)
- **Neden:** localStorage'daki token'ı her XSS okuyabilir. httpOnly cookie ise JS'ten okunamaz.
- **Doğrula:**
  - Login yanıtını bul: `res.json({ token` ya da `return Ok(new { token` gibi bir yapı var mı?
  - `Set-Cookie`/`res.cookie`/`AppendCookie` için `httpOnly`, `secure` ve `sameSite` değerlerine bak.
  - Frontend'de `localStorage.setItem` var mı?
- **Geçer:** Session ya da token, `HttpOnly; Secure; SameSite=Lax|Strict` bayraklı bir cookie ile taşınıyor. Refresh cookie'si `__Secure-` önekiyle ve `Path=/auth` ile sınırlı. `__Host-` öneki Path=/ gerektirir. Path'i `/auth/refresh` yapmak logout'un cookie'yi almasını engeller. SPA için BFF var: token sunucuda kalıyor, tarayıcıda yalnızca session cookie bulunuyor.
- **Tuzak:** Mobil uygulama veya 3. parti API istemcisi için Bearer token kabul edilebilir. Bu durumda madde web istemcisi için değerlendirilir.

### B03 — Token ömrü ve refresh rotation (BLOCKER)
- **Neden:** Çalınan bir token kısa sürede işe yaramaz hale gelmeli. Çalınan bir refresh token ise ilk tekrar kullanımda yakalanmalı.
- **Doğrula:**
  - `expiresIn|exp|ExpireTimeSpan|AccessTokenLifetime` değerlerine bak.
  - Refresh endpoint'i eski token'ı geçersiz kılıp yenisini veriyor mu?
  - Aynı refresh token ikinci kez kullanılınca token ailesinin tamamı iptal ediliyor mu?
- **Geçer:** Access token 5–15 dk ömürlü. Refresh token tek kullanımlık, rotate ediliyor ve DB'de hash'li duruyor. Mutlak ömür sınırı var (ör. 30 gün), rotation bu süreyi uzatmıyor. Rotation tek transaction içinde yapılıyor ve cookie commit'ten sonra set ediliyor.
- **Tuzak:** Expiry tanımlanmamış bir JWT sonsuza kadar geçerlidir.

### B04 — Sunucu tarafı iptal (BLOCKER)
- **Doğrula:**
  - Logout yalnızca cookie'yi mi siliyor, yoksa session veya refresh kaydını da siliyor mu?
  - Parola değişimi ve sıfırlamadan sonra diğer oturumlar düşüyor mu?
- **Geçer:** Logout, parola değişimi ve "tüm cihazlardan çık" sunucu tarafında kayıt siliyor. Access token için kısa ömür veya denylist kullanılıyor.

### B05 — JWT doğrulama (BLOCKER)
- **Doğrula:**
  - `jwt.verify(token, secret)` çağrısında `algorithms` opsiyonu verilmiş mi?
  - `ValidateIssuer/Audience/Lifetime/IssuerSigningKey` değerleri true mu?
  - Secret değeri ne? `secret`, `changeme` veya 32 byte'tan kısa bir değer ❌ demektir.
- **Geçer:** Algoritma sabitlenmiş. iss, aud ve exp doğrulanıyor. Secret ≥256 bit rastgele, ya da RS256/EdDSA anahtar çifti kullanılıyor.
- **Tuzak:** `jwt.decode` yalnızca token'ı çözer, imzayı doğrulamaz.

### B06 — Brute force koruması (BLOCKER)
- **Doğrula:**
  - Login, register, forgot-password, OTP ve verify endpoint'lerinde rate limiter var mı?
  - Limit yalnızca IP'ye göre değil, hesap (e-posta) bazında da uygulanıyor mu?
- **Geçer:** IP başına limit (ör. 10/dk) ve hesap başına limit (ör. 5 başarısız denemede artan gecikme veya 15 dk kilit) var.
- **Tuzak:** Kalıcı hesap kilidi, saldırgana DoS imkânı verir. Kilit süreli olmalı.

### B07 — Kullanıcı enumeration (HIGH)
- **Doğrula:**
  - Login, register ve forgot-password yanıtlarını karşılaştır: farklı mesaj ve status dönüyor mu?
  - Kullanıcı bulunamayınca hash hesaplanmadan erken mi dönülüyor (timing farkı)?
- **Geçer:**
  - Yanıt her durumda tek ve aynı: "E-posta veya parola hatalı".
  - Forgot-password her durumda "Kayıtlıysa e-posta gönderildi" diyor.
  - Kullanıcı yoksa da sahte bir hash hesaplanıyor (timing farkı kapatılmış).

### B08 — Şifre sıfırlama (HIGH)
- **Geçer:** Token en az 128 bit rastgele, DB'de hash'li, tek kullanımlık ve en fazla 30–60 dk geçerli. Kullanıldığında diğer oturumlar iptal ediliyor. Token URL'deyse sayfada `Referrer-Policy: no-referrer` var.

### B09 — MFA (HIGH)
- **Doğrula:** Admin ve yetkili rollerde TOTP veya WebAuthn zorunlu mu? Yönetim için IdP kullanılıyorsa MFA politikası orada açık mı? Koddan görünmüyorsa ❓.

## B. Yetkilendirme

### B10 — Varsayılan deny (BLOCKER)
- **Doğrula:**
  - Route listesini çıkar.
  - Auth middleware global mi, yoksa route bazında mı eklenmiş?
  - `[AllowAnonymous]`/public route'ları tek tek gözden geçir.
- **Geçer:** Auth global uygulanıyor ve public route'lar açıkça işaretli. Ya da her route'ta auth var ve eksik olan yok.

### B11 — IDOR / sahiplik (BLOCKER)
- **Neden:** "Her istekte, istek o kişiye mi ait?" sorusu. En sık rastlanan ve en çok zarar veren açık budur.
- **Doğrula:**
  - `:id`, `{id}` veya `?id=` alan her endpoint'i bul.
  - Sorguda `user_id = currentUser` veya `tenant_id` filtresi var mı?
  - "Önce kaydı getir, sonra sahibini kontrol et" deseni varsa kontrolün gerçekten yapıldığını doğrula.
- **Geçer:** Sahiplik filtresi sorgunun içinde ve her endpoint'te var. Başkasının kaynağı istendiğinde 404 dönüyor.
- **Tuzak:** List endpoint'i filtreli olup detail endpoint'i filtresiz kalabiliyor. Ayrıca update, delete ve export endpoint'leri de ayrı ayrı kontrol edilmeli.

### B12 — Kimlik ve rolün kaynağı (BLOCKER)
- **Doğrula:** `req.headers['x-role'|'x-user-id']`, `body.userId`, `body.role`, `query.isAdmin` gibi kullanımları ara.
- **Geçer:** Kimlik ve rol yalnızca doğrulanmış session'dan veya token claim'inden alınıyor. Rol değişikliği anında etkili oluyor: kritik işlemlerde rol DB'den okunuyor.

### B13 — Mass assignment (HIGH)
- **Doğrula:** `Object.assign(entity, req.body)`, `...req.body`, `update(req.body)`, body'den gelen key'lerle SQL kolon adı üretme, entity'yi doğrudan model binding'e verme gibi kullanımları ara.
- **Geçer:** Her endpoint'in kendine ait bir DTO'su veya allowlist'i var. Hassas alanlar yalnızca ayrı ve yetkili endpoint'lerden değiştirilebiliyor.

### B14 — Admin paneli (HIGH)
- **Geçer:**
  - Admin rolü var ve sunucu tarafında kontrol ediliyor.
  - MFA zorunlu (B09).
  - Admin işlemleri audit log'a yazılıyor (B31).
  - Ek katman olarak IP allowlist, VPN veya Zero Trust (Cloudflare Access vb.) var.
  - Admin paneli ayrı bir subdomain'de ve `robots.txt`'ye yazılmamış.

## C. Girdi ve injection

### B15 — Sunucu tarafı validation (BLOCKER)
- **Doğrula:** Body, query ve params için schema kütüphanesi kullanılıyor mu (zod/joi/class-validator/FluentValidation/DataAnnotations)? Hangi endpoint'ler validator'sız?
- **Geçer:** Her endpoint'te tip, uzunluk ve format kontrolü var, enum'lar allowlist'ten geçiyor. Bilinmeyen alanlar reddediliyor veya yok sayılıyor. Parola dahil her string alanın bir üst uzunluk sınırı var; sınırsız parola argon2 üzerinden CPU DoS'a açıktır.

### B16 — SQL injection (BLOCKER)
- **Doğrula:** `query(` / `execute(` / `FromSqlRaw` / `ExecuteSqlRaw` / `$queryRawUnsafe` / `.raw(` çağrılarında `+`, template string `${` veya `string.Format` kullanılmış mı? Dinamik ORDER BY, kolon veya tablo adları nereden geliyor?
- **Geçer:** Tüm değerler parametre olarak geçiyor. Tanımlayıcılar (kolon, tablo, sıralama) sabit bir allowlist'ten seçiliyor.
- **Tuzak:** `FromSqlInterpolated` güvenlidir, `FromSqlRaw($"...")` güvensizdir.

### B17 — Diğer injection'lar (HIGH)
- **Doğrula:** `exec|spawn|child_process|Process.Start|eval|new Function`, path birleştirme (`path.join(base, userInput)`), Mongo sorgusuna doğrudan body verilmesi (`{$ne:..}`), kullanıcı girdisinden template derlenmesi gibi kullanımları ara.
- **Geçer:** Shell çağrısı yok, ya da argümanlar dizi olarak veriliyor ve allowlist'ten geçiyor. Path normalize ediliyor ve base dizinin içinde kaldığı kontrol ediliyor.

### B18 — SSRF (HIGH)
- **Doğrula:** `fetch|axios|HttpClient|request|got` çağrılarında URL kullanıcıdan mı geliyor (webhook, preview, import, avatar URL)?
- **Geçer:**
  - Host allowlist var ya da çözümlenen IP private, loopback ve link-local aralıkta mı diye kontrol ediliyor (169.254.169.254 dahil).
  - Redirect'ler kapalı veya her redirect yeniden doğrulanıyor.
  - Endpoint auth arkasında.
  - Yanıt doğrudan kullanıcıya yansıtılmıyor.

### B19 — Deserialization (HIGH)
- **Doğrula:** `TypeNameHandling` (≠ None), `BinaryFormatter`, `pickle.loads`, `yaml.load` (safe olmayan), `node-serialize` kullanımlarını ara.

### B20 — Backend XSS (HIGH)
- **Doğrula:**
  - Kullanıcı HTML'i kaydediliyor ya da sunuluyor mu? Sunucu tarafında sanitizer var mı (sanitize-html, HtmlSanitizer)?
  - `res.send(userContent)` ile `text/html` dönülüyor mu?
  - Template'lerde raw output var mı (`<%-`, `@Html.Raw`, `{{{ }}}`)?
- **Geçer:** API JSON dönüyor. HTML ya allowlist sanitizer'dan geçiyor ya da hiç kabul edilmiyor.

## D. Tarayıcı ve transport

### B21 — CSRF (BLOCKER, yalnızca cookie auth varsa)
- **Geçer:** Cookie'ler `SameSite=Lax` veya `Strict`. State değiştiren isteklerde CSRF token (synchronizer veya double-submit) ya da custom header + Origin kontrolü var. GET istekleri yan etkisiz.
- **➖ verilecek durum:** Auth yalnızca `Authorization` header ile yapılıyorsa. Bu durumda B02'ye not düş.

### B22 — CORS (BLOCKER)
- **Doğrula:** `cors(` / `AddCors` / `Access-Control-Allow-Origin` ayarlarına bak. `origin: true`, `'*'` veya `SetIsOriginAllowed(_ => true)` var mı? Bunlardan biri `credentials` ile birlikte kullanılıyor mu?
- **Geçer:** Prod domain'leri açıkça listeli. Origin env'den okunuyor. Gelen origin olduğu gibi geri yansıtılmıyor.

### B23 — HTTPS (BLOCKER)
- **Doğrula:**
  - `http://` ile başlayan prod URL'leri ara.
  - Redirect middleware (`UseHttpsRedirection`, proxy config) var mı?
  - HSTS var mı?
  - Servisler arası iletişim ve DB bağlantıları TLS kullanıyor mu?
- **Geçer:** Trafik TLS 1.2+ ile şifreli. HTTP istekleri 301 ile HTTPS'e yönleniyor. `Strict-Transport-Security: max-age=31536000; includeSubDomains` header'ı var. Preload ancak sonra eklenmeli.

### B24 — Security headers (HIGH)
- **Geçer:**
  - `X-Content-Type-Options: nosniff`
  - `frame-ancestors 'none'` veya `X-Frame-Options: DENY`
  - `Referrer-Policy: strict-origin-when-cross-origin`
  - `Permissions-Policy`
  - HTML sunuluyorsa CSP
  - `X-Powered-By` header'ı ve versiyonu gösteren `Server` header'ı kaldırılmış
- **Doğrula:** Bu header'lar prod'da gerçekten dönüyor mu? `curl -sI https://<host>` ile kontrol et (canlı ortam varsa).

### B25 — Cookie bayrakları (HIGH)
- **Geçer:**
  - Session cookie'si `__Host-` önekli. Bu önek Secure, Path=/ ve Domain olmamasını zorunlu kılar. Path'i daraltılmış cookie'ler (ör. refresh) `__Secure-` önekiyle de kabul edilir.
  - `HttpOnly`, `Secure` ve `SameSite` ayarlı.
  - Max-Age, session ömrüyle uyumlu.

## E. Kötüye kullanım

### B26 — Rate limit ve kaynak sınırları (HIGH)
- **Doğrula:**
  - Global limiter var mı? Pahalı endpoint'lerde (arama, export, AI çağrısı, e-posta gönderimi) ayrı limit var mı?
  - Proxy veya load balancer arkasında gerçek IP alınıyor mu (`trust proxy`, `ForwardedHeaders`)?
  - Body parser'da limit var mı?
  - `limit`/`pageSize` için üst sınır var mı?
  - DB ve HTTP çağrılarında timeout var mı?
- **Geçer:** Yukarıdakilerin hepsi var. Limit aşıldığında 429 ve `Retry-After` dönüyor.
- **Tuzak:** `trust proxy` yanlış ayarlıysa iki sorun çıkar. Ya tüm istekler tek IP'den gelmiş görünür, ya da `X-Forwarded-For` taklit edilip limit atlatılır.

## F. Dosya yükleme

### B27 — Upload (BLOCKER)
- **Doğrula:** multer, IFormFile, busboy ve S3 putObject kullanımlarına bak.
- **Geçer:**
  1. Boyut limiti var.
  2. Uzantı allowlist'i ve magic byte kontrolü var. Sadece `Content-Type` header'ına bakmak yetmez.
  3. Dosya adı sunucuda üretiliyor (UUID). `originalname` dosya yolunda kullanılmıyor.
  4. Dosyalar web root dışında veya private bucket'ta tutuluyor ve kısa ömürlü signed URL ile sunuluyor.
  5. Görseller re-encode ediliyor ve EXIF siliniyor.
  6. SVG ve HTML ya reddediliyor ya da `Content-Disposition: attachment` ve `nosniff` ile sunuluyor.
  7. Upload için kullanıcı başına kota var.
  8. Malware taraması yapılıyor (önerilir).

## G. Secret yönetimi

### B28 — Secret (BLOCKER)
- **Doğrula:**
  - `.gitignore` içinde `.env*` var mı (`!.env.example` hariç)?
  - Repoda `sk_live|sk-|AKIA|-----BEGIN|password=|ConnectionStrings` desenlerini ara.
  - `appsettings.json` içinde secret var mı?
  - Git varsa `gitleaks detect` ile geçmişi tara.
- **Git yoksa:** Geçmiş taraması ❓ olur. Ignore edilmemiş `.env` dosyası yine de ❌ sebebidir.
- **Geçer:** Prod secret'ları secret manager'da (Vault, AWS SM, Azure Key Vault, Doppler) veya platformun env ayarlarında. Repoda yalnızca `.env.example` var. Her ortamın secret'ı ayrı. Anahtarlar minimum yetkili (ör. Stripe restricted key).
- **Sızıntı varsa:** İlk adım **rotate** etmektir. Dosyadan veya geçmişten silmek tek başına yetmez.

## H. Hata ve log

### B29 — Exception handling (BLOCKER)
- **Doğrula:**
  - Global handler'ın döndüğü yanıtta `err.stack`, `err.message` veya `ex.ToString()` var mı?
  - Express 4'te async route'larda hata yakalama var mı? Yoksa unhandled rejection process'i çökertebilir. (Express 5 bunu kendisi yakalar.)
  - `process.on('unhandledRejection')` veya bir log stratejisi var mı?
- **Geçer:** Kullanıcıya `{ error: "Beklenmeyen hata", correlationId }` dönüyor. Detay sunucu log'una yazılıyor. Tek bir hatalı istek process'i düşürmüyor.

### B30 — Prod config (BLOCKER)
- **Doğrula:**
  - `NODE_ENV`/`ASPNETCORE_ENVIRONMENT` değerine bak.
  - `UseDeveloperExceptionPage`, Swagger veya GraphQL introspection prod'da açık mı?
  - Seed'de admin/admin gibi default kullanıcı var mı?
  - Debug endpoint'leri var mı (`/debug`, `/test`, `/env`)?
- **Geçer:** Hepsi kapalı ya da auth arkasında.

### B31 — Audit log (HIGH)
- **Geçer:**
  - Şu olaylar `who/what/when/ip/result` alanlarıyla yapılandırılmış log olarak yazılıyor: login başarı ve başarısızlık, parola değişimi ve sıfırlama, MFA değişikliği, rol değişikliği, admin işlemleri, veri export'u.
  - Log'larda parola, token, kart numarası ve tam TCKN yok (maskeleme veya redaction ile).
  - Log'lar merkezi ve append-only bir yerde toplanıyor, saklama süresi tanımlı.
  - Anomalilerde alarm üretiliyor (ör. başarısız login'lerde ani artış).

## I. Veritabanı

### B32 — DB erişimi (BLOCKER)
- **Doğrula:**
  - Connection string'deki kullanıcıya bak: `postgres`, `sa`, `root` ise ❌.
  - Parolaya bak: varsayılan değer ise ❌.
  - Host'a bak: public ise ❓ (ağ kuralını sor).
  - `sslmode`/`Encrypt=true` ayarına bak.
- **Geçer:** DB private network'te (SG/firewall yalnızca uygulamaya izin veriyor). Uygulama kullanıcısı yalnızca DML yetkisine sahip. Migration ayrı bir kullanıcıyla çalışıyor. Bağlantı TLS ile.

### B33 — BaaS kuralları (BLOCKER)
- **Neden:** Supabase veya Firebase'de tarayıcı DB'ye doğrudan bağlanır. Kural yoksa herkes her şeyi okur ve yazar.
- **Doğrula:**
  - Supabase: her tabloda `alter table ... enable row level security` var mı? Policy'ler `auth.uid()` ile sınırlanmış mı? `service_role` key client kodunda var mı?
  - Firebase: `firestore.rules`/`storage.rules` içinde `allow read, write: if true` veya tarih bazlı test kuralı var mı?
- **Geçer:** Her tabloda RLS açık ve varsayılan deny. Anon key ile yapılan negatif testte başka kullanıcının verisi okunamıyor.
- **➖ verilecek durum:** Tarayıcı DB'ye hiç doğrudan erişmiyorsa.

### B34 — Şifreleme ve migration (MEDIUM)
- **Geçer:** Disk ve at-rest şifreleme açık. TCKN, sağlık ve finans gibi hassas alanlar uygulama seviyesinde şifreli. Şema değişiklikleri versiyonlu migration'larla yapılıyor.

## J. Backup

### B35 — Backup ve restore (BLOCKER, çoğunlukla ❓)
- **Geçer:**
  - Backup otomatik (PITR tercih edilir) ve şifreli.
  - Backup'lar farklı bir hesapta veya bölgede, silinmeye karşı korumalı (immutable veya object lock).
  - Retention tanımlı.
  - **Son 3 ay içinde restore testi yapılmış** ve süresi ölçülmüş.
  - RPO ve RTO yazılı.
- **Not:** Koddan genelde görünmez. ❓ olarak işaretle ve sahibine "son restore testi ne zamandı?" diye sor.

## K. Tedarik zinciri ve CI

### B36 — Dependency (HIGH)
- **Doğrula:** `npm audit --omit=dev`, `dotnet list package --vulnerable --include-transitive`, `pip-audit` çalıştır (ağ erişimi varsa). Lockfile var mı? Dependabot veya Renovate config'i var mı?
- **Geçer:** Kritik veya yüksek seviyede çözülmemiş CVE yok. Lockfile commit'li. Otomatik güncelleme açık.
- **Not:** Komut çalıştırılamadıysa versiyonlara bakarak tahmin yap, sonucu ⚠️ olarak yaz ve "doğrulanmadı" diye belirt.

### B37 — CI güvenlik (HIGH)
- **Doğrula:** `.github/workflows`, `.gitlab-ci.yml`, `azure-pipelines.yml` dosyalarına bak:
  - CodeQL veya Semgrep var mı?
  - gitleaks veya trufflehog var mı?
  - Trivy veya Grype var mı?
  - IaC scan (checkov/tfsec) var mı?
  - Bulgu build'i kırıyor mu?
- **Geçer:** Yukarıdaki taramalar var ve kritik bulgu build'i kırıyor. Main branch protected, PR review zorunlu. CI secret'ları ortam bazında ve minimum yetkili. Workflow'larda `pull_request_target` ile güvensiz checkout yapılmıyor.

## L. Operasyon ve mevzuat

### B38 — Health ve monitoring (HIGH)
- **Doğrula:** Health endpoint config, env, versiyon veya connection string döndürüyor mu? Uptime ve error-rate alarmı var mı?
- **Geçer:** Health yalnızca `{status:"ok"}` döndürüyor. Detaylı health bilgisi iç ağda veya auth arkasında. Uptime monitörü, hata oranı ve latency alarmları kurulu. Alarmların bir sorumlusu var.

### B39 — KVKK / GDPR (HIGH)
- **Geçer:**
  - Yalnızca gereken veri toplanıyor.
  - Kullanıcının verisini silme ve export etme akışı var. Silme işlemi backup ve log politikasıyla uyumlu.
  - Saklama süreleri tanımlı ve süre dolunca veri otomatik siliniyor.
  - Açık rıza alınıyorsa ne zaman, hangi metin versiyonuyla ve hangi IP'den alındığı kaydediliyor.
  - Yurt dışına aktarım (KVKK md. 9; Google, Stripe, OpenAI vb.) için hukuki dayanak var.
  - Veri işleyenlerle DPA imzalanmış.
  - VERBİS yükümlülüğü değerlendirilmiş.
- **Not:** Hukuki kısım ❓ olarak işaretlenir. Kod tarafında silme/export endpoint'i ve consent kaydı aranır.
