# Frontend checklist — detaylar

Her madde şu bölümlerden oluşur: **Doğrula**, **Geçer**, **Tuzak**. Grep sonuçları yalnızca başlangıç noktasıdır; eşleşen her yeri ayrıca oku.

## Güvenlik

### F01 — Bundle'da secret (BLOCKER)
- **Doğrula:**
  - `.env*` dosyalarında ve kodda `NEXT_PUBLIC_|VITE_|REACT_APP_|EXPO_PUBLIC_` önekli değişkenleri bul. Her birine "bu değer herkes tarafından görülse sorun olur mu?" diye sor.
  - Build sonrası çıktıyı tara: `grep -rE "sk_live|sk-|AKIA|secret|private_key" .next/static dist build`
- **Puanlama:** Önekli bir değişkende secret varsa durum ❌ olur, değer şu an bundle'a girmese bile. Önek, değerin client koduna girebileceğini beyan eder ve tek bir client import'u onu sızdırmaya yeter. Build taraması gerçek sızıntıyı teyit eder. `.gitignore` kontrolü F29'da yapılır.
- **Geçer:** Public değişkenlerde yalnızca public değerler var: publishable key, public API URL, analytics ID. Secret gerektiren çağrılar sunucuda (route handler veya BFF) yapılıyor.
- **Tuzak:** Sızmış bir key'i yalnızca env'den taşımak yetmez. Key zaten bundle'da yayılmıştır, önce **rotate** edilmeli.

### F02 — Token saklama (BLOCKER)
- **Doğrula:** `localStorage|sessionStorage` + `token|jwt|auth` geçen yerleri ara. Axios veya fetch interceptor'larında `Authorization: Bearer` ekleniyor mu?
- **Geçer:** Auth httpOnly cookie ile taşınıyor ve istekler `credentials: 'include'` ile yapılıyor. JS token'ı hiç görmüyor. State değiştiren isteklerde backend'in beklediği CSRF token'ı veya custom header gönderiliyor (B21).

### F03 — XSS (BLOCKER)
- **Doğrula:** `dangerouslySetInnerHTML|v-html|innerHTML|outerHTML|insertAdjacentHTML|document.write|eval\(` desenlerini ara. Kullanıcıdan gelen değerlerin `href`/`src` attribute'larına nasıl girdiğine bak.
- **Geçer:** HTML basmadan önce `DOMPurify.sanitize` çağrılıyor. URL'ler `new URL(u).protocol` ile `http:` veya `https:` olarak kontrol ediliyor. Kullanıcı verisi `eval`'e ya da string olarak `setTimeout`'a gitmiyor.

### F04 — CSP, güvenlik header'ları ve 3. parti kod (HIGH)
- **Geçer:**
  - CSP header'ı var. `script-src` nonce veya hash kullanıyor; `'unsafe-inline'` yok.
  - `frame-ancestors` tanımlı.
  - HSTS, `X-Content-Type-Options: nosniff` ve `Referrer-Policy` dönüyor. Bunlar uygulama config'inde veya hosting'de tanımlı olabilir.
  - Yüklenen 3. parti script'lerin listesi ve her birinin ne işe yaradığı belli.
  - Sabit sürüm CDN script'lerinde `integrity` (SRI) var.
- **Puanlama:**
  - CSP var ama `'unsafe-inline'` veya `*` içeriyorsa ⚠️.
  - Header'lar hosting'de tanımlıysa ve koddan görünmüyorsa ❓.
  - `rel="noopener"` eksikliği tek başına ⚠️ sebebi değildir; modern tarayıcılar bunu varsayılan uygular. Düzeltme sütununda an.

### F05 — Build hijyeni (HIGH)
- **Doğrula:**
  - `productionBrowserSourceMaps`, `build.sourcemap: true` ayarları açık mı? `.map` dosyaları public servis ediliyor mu?
  - `console.log` ile token veya kullanıcı verisi yazdırılıyor mu?
  - `http://` ile başlayan API ya da asset URL'i var mı?
- **Geçer:** Source map ya hiç üretilmiyor ya da yalnızca hata takip aracına (F16) gidiyor. Prod'da console'a veri yazılmıyor. Tüm istekler HTTPS üzerinden.

### F06 — UI yetki gizleme (HIGH)
- **Geçer:** Admin butonunu gizlemek yalnızca UX içindir. Her aksiyonun backend'de yetki kontrolü var (B10–B12). Client'ta tutulan rol bilgisi güvenlik kararı için kullanılmıyor.

### F07 — Spam/bot (HIGH)
- **Geçer:** Oturum açmadan kullanılabilen formlarda (login, kayıt, iletişim, yorum, bülten) honeypot alanı veya CAPTCHA var (Turnstile, reCAPTCHA, hCaptcha). Login'de CAPTCHA'nın yalnızca birkaç başarısız denemeden sonra çıkması kabul edilir. CAPTCHA token'ı **sunucuda** doğrulanıyor. Endpoint'te rate limit var.

## SEO ve paylaşım

### F08 — Meta (HIGH)
- **Doğrula:**
  - Her route'ta title ve description var mı? Değerleri sayfadan sayfaya farklı mı? Dinamik sayfalarda (`/post/[id]`) içerikten üretiliyor mu?
  - `<html lang="tr">` tanımlı mı?
  - `rel=canonical` var mı?
- **Geçer:** Title ~50–60 karakter, description ~150–160 karakter. Title'lar marka adını içeriyor ve birbirini tekrar etmiyor. Canonical ve lang tanımlı. Çok dilli sitelerde her dil sürümü `hreflang` ile birbirine bağlı (Next'te `alternates.languages`).

### F09 — robots.txt (HIGH)
- **Geçer:**
  - Prod'da `Disallow: /` yok.
  - Admin veya gizli yollar listede yok (bu, yolları herkese ilan eder).
  - `Sitemap: https://.../sitemap.xml` satırı var.
  - Staging ve preview ortamları `X-Robots-Tag: noindex` ile işaretli ve basic auth arkasında.
- **Tuzak:** Staging'deki `Disallow: /` dosyası prod'a da kopyalanıyor. Ortama göre üretilmesi gerekir.

### F10 — sitemap.xml (MEDIUM)
- **Geçer:** Yalnızca 200 dönen, canonical ve index'lenebilir URL'leri içeriyor. Login, admin ve teşekkür sayfaları sitemap'te yok. Search Console'a gönderilmiş (gönderim ❓ olarak sorulur).

### F11 — Open Graph (MEDIUM)
- **Geçer:** `og:title`, `og:description`, `og:image` (1200×630, mutlak HTTPS URL), `og:url` ve `twitter:card=summary_large_image` tanımlı.

### F12 — İkonlar (MEDIUM)
- **Geçer:** `favicon.ico` veya svg, `apple-touch-icon` (180×180) ve `manifest.webmanifest` var.

## Hata ve durum ekranları

### F13 — 404/500 (HIGH)
- **Doğrula:** Özel bir 404 sayfası var mı? Bilinmeyen bir route gerçekten 404 status kodu dönüyor mu? SPA'larda hosting her yolu 200 ile `index.html`'e yönlendirir, bu durum soft 404'tür. 500 hatası ve error boundary var mı?
- **Geçer:** Markaya uygun 404 sayfası ana sayfaya ve aramaya link veriyor, status kodu 404. Özel 500 sayfası var. Bileşen hataları beyaz ekrana yol açmıyor.

### F14 — Loading (HIGH)
- **Geçer:** Veri çeken her ekranda skeleton veya spinner var. Submit sırasında buton disabled ve "Gönderiliyor…" gibi bir metin gösteriyor. Uzun işlemlerde iptal veya timeout var.

### F15 — Form hataları (HIGH)
- **Geçer:**
  - Hata mesajı alanın yanında görünüyor ve `aria-describedby` ile o alana bağlı. Alan `aria-invalid` ile işaretli. Focus ilk hatalı alana gidiyor.
  - Sunucu hatasında kullanıcının girdiği değerler korunuyor.
  - `res.ok` kontrol ediliyor. Hata durumunda başarı akışı (redirect, token kaydetme vb.) çalışmıyor.
  - `alert()` kullanılmıyor.
  - Kullanıcıya teknik hata metni değil, anlaşılır bir mesaj gösteriliyor.
  - Inputlarda doğru `type`, `autocomplete` ve `inputmode` değerleri var.

### F16 — Hata takibi (HIGH)
- **Geçer:** Sentry veya benzeri bir araç kurulu. Release etiketleri ve source map yüklemesi yapılıyor. PII scrub ayarları açık. Alarm kuralları tanımlı.

## Hukuk (KVKK + GDPR)

### F17 — Çerez onayı (BLOCKER)
- **Doğrula:** GA, GTM, Meta Pixel, Hotjar, Clarity gibi script'ler nerede ve hangi koşulla yükleniyor? Onaydan önce ağ isteği gidiyor mu? DevTools'ta Network ve Cookies sekmelerine ilk yüklemede bak.
- **Geçer:**
  - İlk ziyarette yalnızca zorunlu çerezler var.
  - Banner'da "Kabul et", "Reddet" ve "Tercihler" seçenekleri eşit ağırlıkta. Önceden işaretli kutu yok.
  - Kullanıcının seçimi kaydediliyor ve footer'daki "Çerez tercihleri" linkiyle değiştirilebiliyor.
  - Google araçları Consent Mode v2 ile çalışıyor: varsayılan değer `denied`.
- **Tuzak:** "Siteyi kullanarak çerezleri kabul etmiş sayılırsınız" ifadesi geçerli bir onay değildir.

### F18 — Gizlilik / KVKK metinleri (BLOCKER)
- **Geçer:**
  - Gizlilik politikası var.
  - KVKK aydınlatma metni var. Metin şunları kapsıyor: veri sorumlusu, amaçlar, aktarılan taraflar (yurt dışı dahil), hukuki sebep, toplama yöntemi ve md. 11 kapsamındaki haklar.
  - Çerez politikası var.
  - Açık rıza gereken işlemler (pazarlama, yurt dışı aktarım vb.) için **ayrı ve isteğe bağlı** bir onay kutusu var.
  - Ticari elektronik ileti için ayrı bir izin alınıyor (İYS).
  - Kişisel veri toplayan formların yanında aydınlatma metnine link var.
  - AB kullanıcıları için gizlilik politikası GDPR md. 13 bilgilerini içeriyor: amaç, hukuki dayanak, saklama süresi, haklar, şikâyet hakkı, AB dışına aktarım. AB'de şirket yoksa md. 27 kapsamında AB temsilcisi atanmış.
  - Yurt dışına aktarım (GA, Stripe, bulut vb.) KVKK'nın 2024 değişikliğinden sonraki rejime göre değerlendirilmiş: uygun güvence (standart sözleşme vb.) var, standart sözleşme Kurul'a bildirilmiş ya da açık rıza alınmış.
- **Not:** Metnin içeriğinin hukuken yeterli olup olmadığı ❓ olarak işaretlenir, hukuk ekibine sorulur.

### F19 — Kullanım koşulları (HIGH)
- **Geçer:** Kullanım koşulları sayfası var. E-ticaret yapılıyorsa mesafeli satış sözleşmesi, ön bilgilendirme formu, iade ve iptal koşulları da var. Bu sayfalar footer'dan ve ödeme adımından erişilebilir.

### F20 — İletişim (MEDIUM)
- **Geçer:** Şirket unvanı, adres, e-posta veya telefon ve KVKK başvuru kanalı açıkça yazılı.

## Analytics

### F21 — Analytics (HIGH)
- **Geçer:**
  - Analytics yalnızca onaydan sonra yükleniyor (F17).
  - URL'lerde ve event parametrelerinde e-posta, telefon veya isim gibi PII yok.
  - Gerçek ölçüm ID'si kullanılıyor (`G-XXXX` gibi placeholder değil).
  - Temel conversion event'leri tanımlı (form gönderimi, kayıt, satın alma).
  - Staging trafiği prod verisine karışmıyor.

## UX ve performans

### F22 — Mobil (HIGH)
- **Doğrula:** `<meta name="viewport" content="width=device-width, initial-scale=1">` var mı? Kodda `width: 1200` gibi sabit piksel genişlikler var mı? 375px genişlikte yatay scroll oluşuyor mu?
- **Geçer:** Layout akışkan. Dokunma hedefleri en az 44×44px. Input font-size en az 16px (iOS'un otomatik zoom yapmaması için).

### F23 — Görseller (HIGH)
- **Geçer:**
  - Görseller WebP veya AVIF formatında, `srcset`/`sizes` ile duyarlı sunuluyor. Next.js'te `next/image` kullanılıyor.
  - `width` ve `height` tanımlı (yoksa CLS oluşur).
  - Ekranın altında kalan görseller lazy yükleniyor. LCP görselinde `fetchpriority="high"` var (Next ≤15'te `priority` de olur) ve bu görsel lazy yüklenmiyor.
  - Kodda referans verilen tüm dosyalar gerçekten mevcut.

### F24 — Core Web Vitals (HIGH)
- **Doğrula:**
  - Canlı veya preview URL varsa PageSpeed Insights ya da `npx lighthouse <url> --preset=desktop` ile ölç. Mobil profil de ölçülmeli.
  - URL yoksa ❓ işaretle. Kodda ağır bundle ve render-blocking script olup olmadığına bak.
- **Geçer:** Mobil profilde LCP < 2.5 sn, INP < 200 ms, CLS < 0.1.

### F25 — Erişilebilirlik (HIGH)
- **Geçer:**
  - `<img>` etiketlerinde `alt` var. Dekoratif görsellerde `alt=""` kullanılıyor.
  - Her input bir `<label>` ile ilişkilendirilmiş. Yalnızca placeholder kullanmak yetmez.
  - Normal metinde kontrast oranı en az 4.5:1.
  - Tüm işlemler klavye ile yapılabiliyor ve focus görünür.
  - Semantik başlık sırası korunuyor ve sayfada tek `h1` var.
- **Doğrula:** Mümkünse `npx @axe-core/cli <url>` çalıştır.

### F26 — Çapraz tarayıcı (MEDIUM)
- Bu madde ❓ olarak işaretlenir ve hangi cihaz/tarayıcı kombinasyonlarının test edildiği sorulur.

### F27 — CTA (MEDIUM, koşullu)
- **Geçer:** Landing sayfalarında ilk ekranda tek ve net bir birincil CTA var. Mobilde sabit CTA kullanılıyorsa içeriği, çerez banner'ını veya `env(safe-area-inset-bottom)` alanını örtmüyor.
- **Ne zaman ➖:** Uygulama içi ekranlar için bu madde uygulanamaz.

### F28 — Teşekkür sayfası (MEDIUM, koşullu)
- **Geçer:** Form gönderildikten sonra kullanıcı ayrı bir URL'ye yönlendiriliyor ve conversion bu URL'ye bağlı. Sayfa `noindex` ve sitemap'te yok.

## Tedarik zinciri

### F29 — Dependency ve framework CVE (HIGH)
- **Doğrula:**
  - `npm audit --omit=dev` çalıştır (ağ erişimi varsa).
  - Framework sürümünü bilinen kritik açıklarla karşılaştır. Örnek: Next.js <14.2.25 ve <15.2.3 sürümleri CVE-2025-29927 middleware bypass açığından etkilenir.
  - Lockfile var mı?
  - `.gitignore` dosyası `.env*` kalıbını kapsıyor mu?
- **Geçer:** Kritik veya yüksek seviyede çözülmemiş CVE yok. Lockfile commit'li. Dependabot veya Renovate açık.
- **Puanlama:** Lockfile yoksa ❌. Komut çalıştırılamadıysa ve sürümden tahmin ettiysen ⚠️ yaz ve "doğrulanmadı" diye belirt.
