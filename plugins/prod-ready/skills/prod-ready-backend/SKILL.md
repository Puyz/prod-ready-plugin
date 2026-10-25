---
name: prod-ready-backend
description: Use when writing or reviewing backend/API code that handles auth, login, sessions, tokens, permissions, user data, SQL, file uploads, secrets or admin features; and when asked whether a backend is ready for production, go-live or launch ("prod'a hazır mı", "production'a çıkmadan önce kontrol et", "güvenlik kontrolü", "security audit", "pre-launch checklist").
---

# Prod-Ready Backend

## Genel bakış
Production'a çıkacak bir backend için 39 maddelik güvenlik ve operasyon listesi. Stack'ten bağımsızdır. İki modu var:

- **Build modu:** Kod yazarken ilgili maddeler varsayılan davranıştır. Sorulmasa da uygulanır.
- **Audit modu:** Her madde kanıtla puanlanır ve sonunda GO / NO-GO kararı çıkar.

Maddelerin detayları (neden, nasıl doğrulanır, geçme kriteri) [references/checklist.md](references/checklist.md) dosyasındadır. Stack'e özel kod örnekleri için:

- [references/stack-dotnet.md](references/stack-dotnet.md)
- [references/stack-node.md](references/stack-node.md)

Frontend tarafı için `prod-ready-frontend` skill'ini kullan.

## Mod seçimi
- Endpoint, auth, sorgu, upload veya config yazılıyor ya da değiştiriliyorsa **Build modu** geçerlidir.
- "Hazır mı / audit / kontrol et / review" deniyorsa **Audit modu** geçerlidir.

## Build modu
Dokunduğun alanın maddelerini uygula. Proje stack'ine uyan referans dosyasındaki deseni kullan.

| Yazdığın şey | Uygulanacak maddeler |
|---|---|
| Login / register / şifre sıfırlama | B01–B09, B15, B21, B22, B25, B26, B31 |
| Yeni endpoint | B10–B16, B26, B29 |
| Kaynak döndüren endpoint (`/x/:id`) | B11 (sahiplik filtresi sorgunun içinde olmalı) |
| Update endpoint'i | B13 (DTO allowlist) |
| Dışarıya HTTP isteği atan kod | B18 |
| Dosya yükleme | B27 |
| Config, secret, deploy | B23–B25, B28, B30, B32 |
| Admin özelliği | B09, B12, B14, B31 |

Bir maddeden bilerek sapıyorsan koda gerekçeli bir yorum yaz: `// security: <madde> uygulanmadı çünkü <neden>; <ne zaman düzeltilecek>`.

## Audit modu
1. Stack'i tespit et ve ilgili referans dosyasını oku.
2. `references/checklist.md` dosyasını oku. **B01–B39 arasındaki her ID raporda bir satır olarak yer almalı.** Bir satırın atlanması, raporun eksik olduğu anlamına gelir.
3. Her madde için kanıt ara. Kanıt `dosya:satır` biçiminde olmalı ya da çalıştırdığın komutun çıktısı olmalı.
4. Raporu aşağıdaki şablona göre doldur.

**Durum değerleri:**
- ✅ Geçti: koddan kanıt gösterilebiliyor.
- ❌ Kaldı: açık var.
- ⚠️ Kısmi: kısmen uygulanmış.
- ➖ Uygulanamaz: madde bu projeye uymuyor. Gerekçesi yazılmalı (ör. "cookie auth yok, CSRF uygulanamaz").
- ❓ Manuel doğrula: koddan doğrulanamıyor. Altyapı, süreç ve dış hesaplarla ilgili maddeler buraya girer: backup restore, DB ağ erişimi, MFA, monitoring, branch protection.

**Kanıt yoksa ✅ verilmez.** "Muhtemelen vardır" diye yazmak ❓ demektir.

**Puanlama kuralları:**
- **Karma madde:** Bir maddenin bir kısmı koddan doğrulanabiliyor, bir kısmı doğrulanamıyor olabilir (ör. B23: HSTS kodda görünür, proxy TLS ayarı görünmez). Bu durumda doğrulanabilen kısımlar arasındaki en kötü durumu yaz. Doğrulanamayan kısmı ❓ bölümüne soru olarak ekle.
- **Var olmayan özellik:**
  - Madde, özellik olmasa da gereken bir güvenlik özelliğini tarif ediyorsa ❌ ver. Örnekler: logout/iptal (B04), admin rolü varken MFA (B09), audit log (B31).
  - Özelliğin kendisi isteğe bağlıysa ve projede yoksa ➖ ver ve "eklenirse uygulanmalı" notu düş. Örnek: şifre sıfırlama akışı (B08).
- **Uygulama içi auth ve MFA:** Auth uygulamanın içinde yazılmışsa ve MFA kodu yoksa B09 ❌ olur. B09 yalnızca auth bir dış IdP'deyse ❓ olabilir.
- **Lockfile yoksa** B36 ❌ olur. "Komut çalıştırılamadı" kuralına göre ⚠️ vermek yalnızca lockfile varken geçerlidir.
- **Secret değerleri:** Değeri rapora veya terminale yazma. Raporda yalnızca önekini (`sk_live_…`) ya da "varsayılan/zayıf" nitelemesini kullan. Karşılaştırma yapman gerekiyorsa çıktı üretmeyen bir komutla yap.
- **Rotate kararı:** Secret proje dizininde ignore edilmemiş bir dosyada düz metin duruyorsa, git geçmişinde varsa ya da bir public endpoint'ten okunabiliyorsa, sızmış kabul et ve "önce rotate" önerisini yaz.
- **Kütüphane ve framework varsayılanları kanıt sayılır** (ör. helmet 7'nin HSTS ve nosniff'i, ASP.NET'in `UseExceptionHandler`'ı). Bunun koşulu, kullanılan sürümün bilinmesidir. Sürüm bilinmiyorsa ⚠️ ver.
- **Kod dışından ayarlanabilen kısımlar:** Bir ayar koddan başka bir yerden de verilebiliyorsa ve kodda yoksa o kısım ❓ olur, ❌ değil. Örnekler: DB TLS'i `PGSSLMODE` env değişkeniyle ya da sunucu tarafında zorunlu kılınabilir. HTTPS redirect proxy'de yapılabilir.
- **Cookie yoksa:** B21 ve B25 ➖ olur. Gerekçeye "B02'ye bağlı" yaz.
- **Express'te B10:** Public route'lar global auth middleware'inden önce tanımlanmışsa ya da ayrı bir public router'da duruyorsa "açıkça işaretli" sayılır. Yalnızca route bazında auth kullanılıyorsa her route tek tek listelenir. Auth'suz route'ların hiçbirinin public olduğu belirtilmemişse ❌.
- **Yokluğun kanıtı:** Bir şeyin olmadığını söyleyip ✅ veriyorsan (ör. B19), kanıt sütununa taradığın kapsamı yaz: "tüm dosyalar okundu (N satır)" ya da "`<desen>` ile `src/**` tarandı, 0 eşleşme".
- **Aynı kök neden:** Bir bulgu birden fazla maddeyi ihlal ediyorsa her maddede ❌ ver. "Önce yapılacaklar" bölümünde ise tek bir iş olarak yaz.
- **Sürüm CVE'leri** B36'da puanlanır. CVE'den etkilenen diğer maddelerde (ör. jsonwebtoken → B05) yalnızca düzeltme sütununda an.
- **Kapsam:** Kanıt toplamak için frontend kodunu okuyabilirsin (ör. B02 için localStorage kullanımı). Frontend'e ait bulguları "ek bulgular" bölümüne yaz.

**Dil:** Raporu kullanıcının yazdığı dilde yaz. Tablo başlıkları da o dile çevrilebilir. Kullanıcının ya da ortamın talimatları emoji kullanımını yasaklıyorsa durumlar için şu karşılıkları kullan: PASS / FAIL / PARTIAL / N/A / MANUAL.

**Çalıştırılamayan araçlar:** `npm audit`, `curl`, `gitleaks` gibi araçlar çalıştırılamıyorsa kaynak koda bakarak puanla. Çalıştırılması gereken komutu ❓ bölümüne yaz.

**Önem dereceleri:**
- BLOCKER: prod'a çıkışı durdurur.
- HIGH: ilk hafta içinde kapatılmalı.
- MEDIUM: iyileştirme.

**Karar kuralı:**
- Herhangi bir BLOCKER ❌ veya ⚠️ ise **NO-GO**.
- BLOCKER ❓ ya da HIGH ❌/⚠️ varsa **GO (şartlı)**. Şartlar "Önce yapılacaklar" bölümüne yazılır: her BLOCKER ❓ için kimin doğrulayacağı, her HIGH için kapanış tarihi (en geç yayından 1 hafta sonra).
- Diğer durumlarda **GO**.

**"Önce yapılacaklar" sırası:**
1. Sızmış secret'ların rotate edilmesi
2. Kimlik doğrulama gerektirmeden sömürülebilen açıklar
3. Giriş yapmış kullanıcının sömürebileceği açıklar
4. Diğerleri

Takvim baskısı varsa ilk iki grubun kapanmasının pazarlık konusu olmadığını açıkça yaz.

### Rapor şablonu
```
## Backend Prod Readiness — <proje> — <tarih>
**Karar: NO-GO | GO (şartlı) | GO** — <tek cümle gerekçe>
Özet: BLOCKER x❌ y⚠️ z❓ · HIGH x❌ y⚠️ z❓ · MEDIUM x❌ y⚠️ z❓ · ✅ n · ➖ n

| ID | Madde | Önem | Durum | Kanıt | Düzeltme |
|----|-------|------|-------|-------|----------|
| B01 | Parola hash | BLOCKER | ❌ | api/server.js:32 md5 | argon2id'ye geç, login'de rehash |
... (B01–B39 eksiksiz)

### ❓ Manuel doğrulanacaklar (sahibine sorulacak)
- B35: Son restore testi ne zaman yapıldı? RPO/RTO nedir?

### Listede olmayan ek bulgular
- <checklist dışında kalan ama önemli olan her şey; build kırığı, mantık hatası vb.>

### Önce yapılacaklar
1. <sızmış secret varsa ilk sırada rotate edilmeli>
```

## Madde listesi
| ID | Önem | Madde |
|---|---|---|
| **A. Kimlik doğrulama** |||
| B01 | BLOCKER | Parola Argon2id/bcrypt ile hashleniyor. MD5/SHA/düz metin yok. |
| B02 | BLOCKER | Token httpOnly + Secure + SameSite cookie'de. localStorage'da veya JSON body'de dönmüyor. SPA'da BFF kullanılıyor. |
| B03 | BLOCKER | Access token 5–15 dk ömürlü. Refresh token rotation ve reuse detection var, refresh token DB'de hash'li tutuluyor. |
| B04 | BLOCKER | Logout ve parola değişimi sunucu tarafında oturumları iptal ediyor. |
| B05 | BLOCKER | JWT'de algoritma sabit (`none` reddediliyor). iss/aud/exp doğrulanıyor. Secret ≥256 bit ve rastgele. |
| B06 | BLOCKER | Login, register, şifre sıfırlama ve OTP'de IP + hesap bazlı deneme sınırı var. Aşılınca gecikme veya geçici kilit devreye giriyor. |
| B07 | HIGH | Hata mesajları jenerik. Kullanıcının var olup olmadığı yanıt mesajından, status kodundan veya yanıt süresinden anlaşılmıyor. |
| B08 | HIGH | Şifre sıfırlama token'ı tek kullanımlık, kısa ömürlü ve hash'li. |
| B09 | HIGH | Admin ve yetkili hesaplarda MFA zorunlu. |
| **B. Yetkilendirme** |||
| B10 | BLOCKER | Varsayılan deny: auth global olarak açık, public endpoint'ler açıkça işaretli. |
| B11 | BLOCKER | IDOR koruması: her sorgu user/tenant ile filtreleniyor. Başkasının kaynağına erişimde 404 dönüyor. |
| B12 | BLOCKER | Rol ve userId header'dan, body'den veya query'den alınmıyor. Doğrulanmış oturumdan geliyor. |
| B13 | HIGH | Mass assignment yok. DTO allowlist var, `role`/`isAdmin`/`ownerId`/`password_hash` bind edilmiyor. |
| B14 | HIGH | Admin: ayrı rol + MFA + audit log. Ek katman olarak IP allowlist veya VPN var. |
| **C. Girdi ve injection** |||
| B15 | BLOCKER | Sunucu tarafında schema validation var (tip, uzunluk, format). Client tarafı validation sadece UX içindir. |
| B16 | BLOCKER | SQL sorguları parametreli. String birleştirme yok. ORDER BY ve kolon adları allowlist'ten geliyor. |
| B17 | HIGH | Diğer injection türleri yok: OS komutu, NoSQL operatörü, path traversal, template injection. |
| B18 | HIGH | SSRF koruması: kullanıcıdan gelen URL'ler allowlist'ten geçiyor. Private IP'ler ve 169.254.169.254 bloklanıyor. DNS rebinding kontrolü var. |
| B19 | HIGH | Güvensiz deserialization yok. |
| B20 | HIGH | Kullanıcı HTML'i sanitize ediliyor. Content-Type doğru, kullanıcı içeriği `text/html` olarak dönmüyor. |
| **D. Tarayıcı ve transport** |||
| B21 | BLOCKER | Cookie auth kullanılıyorsa CSRF koruması var (SameSite + token/custom header). GET istekleri yan etkisiz. |
| B22 | BLOCKER | CORS origin allowlist kullanıyor. `*` + credentials yok, origin reflect edilmiyor. |
| B23 | BLOCKER | Her yerde HTTPS var, HTTP→HTTPS redirect yapılıyor. TLS 1.2+ ve HSTS açık. |
| B24 | HIGH | Security header'lar var: CSP, nosniff, frame-ancestors, Referrer-Policy, Permissions-Policy. `X-Powered-By` header'ı kapalı. |
| B25 | HIGH | Cookie'lerde `__Host-` öneki, HttpOnly, Secure, SameSite ve uygun Max-Age var. |
| **E. Kötüye kullanım** |||
| B26 | HIGH | Global ve endpoint bazlı rate limit var, 429 + Retry-After dönüyor. Proxy arkasında gerçek IP alınıyor (`trust proxy`). Body boyutu limitli, sayfalama için üst limit var, timeout ayarlı. |
| **F. Dosya** |||
| B27 | BLOCKER | Upload'larda boyut limiti, uzantı allowlist'i ve magic byte kontrolü var. Dosya adları rastgele üretiliyor. Dosyalar web root dışında veya private storage'da tutuluyor ve signed URL ile sunuluyor. HTML/SVG yüklemeleri engelleniyor veya `attachment` olarak sunuluyor. |
| **G. Secret** |||
| B28 | BLOCKER | Secret'lar `.env` (gitignore'lu, yanında `.env.example`) veya secret manager'da. Git geçmişinde secret yok. Sızan secret rotate edildi. Her ortamın secret'ı ayrı, yetkileri minimum. |
| **H. Hata ve log** |||
| B29 | BLOCKER | Global exception handler var. Kullanıcıya jenerik mesaj ve correlation id dönüyor, stack trace dönmüyor. Async hatalar yakalanıyor ve process'i çökertmiyor. |
| B30 | BLOCKER | Prod config: debug kapalı. Swagger kapalı veya korumalı. Default credential yok. |
| B31 | HIGH | Audit log tutuluyor: auth olayları, rol değişiklikleri, admin işlemleri. Log'larda parola, token veya PII yok. Log'lar merkezi bir yerde toplanıyor ve alarm kuruluyor. |
| **I. Veritabanı** |||
| B32 | BLOCKER | DB public internete kapalı. Uygulama DB'ye least-privilege bir kullanıcıyla bağlanıyor (superuser değil, default parola değil). Bağlantı TLS ile. |
| B33 | BLOCKER | BaaS (Supabase/Firebase) kullanılıyorsa her tabloda RLS/Rules açık, varsayılan deny. Anon key ile negatif test yapılmış. service_role key client'ta yok. |
| B34 | MEDIUM | Hassas alanlar şifreli saklanıyor. Migration'lar versiyonlu. |
| **J. Backup** |||
| B35 | BLOCKER | Backup otomatik, şifreli ve ayrı hesapta/bölgede. Restore testi yapılmış. RPO/RTO tanımlı. |
| **K. Tedarik zinciri ve CI** |||
| B36 | HIGH | Dependency scan yapılıyor. Kritik CVE yok. Lockfile commit'li. |
| B37 | HIGH | CI'da SAST, secret scan ve container/IaC scan var. Kritik bulgu build'i kırıyor. Branch protection açık. |
| **L. Operasyon ve mevzuat** |||
| B38 | HIGH | Health endpoint bilgi sızdırmıyor. Monitoring, alerting ve uptime takibi var. |
| B39 | HIGH | KVKK/GDPR: veri minimizasyonu, silme/export süreci, saklama süreleri ve consent kaydı var. Yurt dışına aktarım ve işleyenlerle DPA ele alınmış. |

## Sık yapılan hatalar
| Hata | Gerçek |
|---|---|
| "Token header'da, cookie yok, o yüzden CSRF yok, sorun yok" | CSRF için ➖ doğru. Ama token JS'de durduğu için B02 ❌ olur: XSS = hesap ele geçirme. |
| "ID'ler UUID, IDOR olmaz" | UUID'ler log'larda, URL'lerde ve referer'da sızar. B11 sorguda sahiplik filtresi ister. |
| "Admin paneli IP kilitli, yeter" | IP kilidi ek bir katmandır. B09, B12 ve B14 yine gerekir. |
| "Helmet var, header'lar tamam" | Helmet'in varsayılan CSP'si API için genelde yeterlidir. Ama CORS ve cookie ayarları ayrıca kontrol edilir. |
| Koddan göremediğin maddeye ✅ vermek | O madde ❓ olur. Backup, MFA ve DB ağ erişimi koddan görünmez. |
| Sızmış secret'ı "dosyadan sil" diye önermek | Önce rotate edilir. Git geçmişinde veya kopyalarında hâlâ durabilir. |
