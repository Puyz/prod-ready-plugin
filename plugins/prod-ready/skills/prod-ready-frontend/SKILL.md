---
name: prod-ready-frontend
description: Use when building or reviewing web frontend pages, forms, login UI, layouts, analytics/tracking scripts, cookie banners or SEO setup; and when asked whether a website or web app is ready for production, go-live or launch ("site yayına hazır mı", "production öncesi frontend kontrolü", "SEO/KVKK kontrolü", "pre-launch checklist", "launch audit").
---

# Prod-Ready Frontend

## Genel bakış
Production'a çıkacak bir web frontend'i için 29 maddelik bir kontrol listesi. Kapsadığı alanlar: güvenlik, SEO, hata ekranları, KVKK/GDPR, analytics, UX ve performans. Stack'ten bağımsızdır.

İki modda çalışır:
- **Build modu:** Kod yazarken ilgili maddeler varsayılan davranış olarak uygulanır.
- **Audit modu:** Her madde kanıtla puanlanır ve sonunda GO / NO-GO kararı verilir.

Ek dosyalar:
- Maddelerin detayları: [references/checklist.md](references/checklist.md)
- Stack'e özel desenler:
  - [references/stack-nextjs.md](references/stack-nextjs.md)
  - [references/stack-spa.md](references/stack-spa.md) (React/Vite/Vue)

Backend güvenliği bu skill'in kapsamında değil. O taraf için `prod-ready-backend` skill'ini kullan. Bu skill'deki F06, gerçek yetki kontrolü için backend'deki B10–B12 maddelerine dayanır.

## Mod seçimi
- Sayfa, form, layout, script veya config yazılıyorsa **Build modu**.
- Kullanıcı "hazır mı / audit / kontrol et / yayına çıkıyoruz" diyorsa **Audit modu**.

## Build modu
| Yazdığın şey | Uygulanacak maddeler |
|---|---|
| Yeni sayfa | F08, F11, F13, F22, F23, F25 |
| Form | F07, F14, F15, F25; KVKK metni linki (F18) |
| Login / auth UI | F02, F06, F15 |
| Kullanıcı içeriğini render eden kod | F03 |
| 3. parti script / analytics / pixel | F04, F17, F21 |
| Env / config / build ayarı | F01, F05, F09 |
| Landing sayfası | F27, F28 |

Bir maddeden bilerek sapıyorsan bunu koda yorum olarak yaz: `// launch: <madde> atlandı çünkü <neden>`.

## Audit modu
1. Stack'i tespit et ve ilgili referans dosyasını oku.
2. `references/checklist.md` dosyasını oku. **F01–F29 arasındaki her ID raporda bir satır olarak yer almalı.** Bir ID'yi atlamak raporu eksik bırakır.
3. Her madde için kanıt topla: `dosya:satır`, bir komutun çıktısı veya canlı URL'den bir ölçüm.
4. Raporu aşağıdaki şablonla doldur.

**Durum değerleri:**
- ✅ Kanıtla geçti
- ❌ Kaldı
- ⚠️ Kısmi
- ➖ Uygulanamaz (gerekçesiyle; ör. "landing değil, uygulama içi ekran" → F27)
- ❓ Manuel doğrula: koddan doğrulanamayanlar. Örnekler: Lighthouse skoru, gerçek cihazda test, Search Console, hukuki metnin içeriğinin yeterliliği.

**Kanıt yoksa ✅ verilmez.**

**Puanlama kuralları:**
- **Karma madde:** Bir maddenin bir kısmı koddan doğrulanabiliyor, bir kısmı doğrulanamıyorsa (ör. F10: dosya yok + Search Console), doğrulanabilen kısımlar arasındaki en kötü durumu yaz. Doğrulanamayan kısmı ❓ bölümüne soru olarak ekle.
- **Framework varsayılanları kanıt sayılır.** Kodda açıkça yazmıyor diye ❌ verme. Örnek: Next App Router viewport meta etiketini kendisi ekler (F22). Vite'ta `build.sourcemap` varsayılan olarak `false`'tur (F05).
- **F01:** Önekli değişkende secret varsa durum ❌ olur. Bu kural build taramasından önce gelir. Proje build edilemiyorsa kaynak koda bakarak puanla ve build taramasını ❓ bölümüne yaz.
- **F06:** Rol bazlı UI yoksa ve frontend rol/kimlik bilgisini kendisi göndermiyorsa ➖ ver. Frontend rolü header'da, body'de veya query'de gönderiyorsa ❌ ver. Backend'deki yetki açıklarını "ek bulgular" bölümüne yaz ve `prod-ready-backend`'e yönlendir.
- **F07:** Oturum açmadan kullanılabilen her form bu maddenin kapsamındadır, login formu da dahil.
- **F13:** Yalnızca framework'ün varsayılan 404 sayfası varsa (status kodu doğru ama sayfa özel değil) ⚠️ ver.
- **F19:** Ödeme SDK'sı, `/checkout` ya da `/orders` endpoint'i veya ödeme sağlayıcı anahtarı görüyorsan e-ticaret var kabul et. Kullanıcı aksini söylüyorsa bu çelişkiyi ❓ olarak sor.
- **F24 / F26:** Ölçüm veya test kaydı yoksa durum her zaman ❓ olur. Koddan görünen riskleri "Kanıt" sütununa yaz.
- **F28:** Bu madde yalnızca lead, iletişim, kayıt veya satın alma formu varsa geçerlidir. Bunlardan hiçbiri yoksa ➖ ver.
- **F29:** Lockfile yoksa ❌ ver; bu kural "sürümden tahmin → ⚠️" kuralından önce gelir. Proje git reposu değilse Dependabot ve commit maddelerini ❓ olarak sor.
- **Çalıştırılamayan araçlar:** Build, `npm audit`, Lighthouse veya axe çalıştırılamıyorsa kaynak koda bakarak puanla. Çalıştırılması gereken komutu ❓ bölümüne yaz.
- **Secret değerleri:** Değeri rapora yazma. Önek (`sk-…`) yazman yeterli.
- **Kapsam:** Kanıt toplamak için backend kodunu okuyabilirsin (ör. F02 için cookie ayarı). Backend bulgularını ayrıntılandırma, "ek bulgular" bölümünde kısaca belirt.

**Dil:** Raporu kullanıcının dilinde yaz. Kullanıcının ya da ortamın talimatları emoji kullanımını yasaklıyorsa durumları şöyle yaz: PASS / FAIL / PARTIAL / N/A / MANUAL.

**Önem dereceleri:**
- BLOCKER: yayını durdurur.
- HIGH: ilk hafta içinde düzeltilir.
- MEDIUM: iyileştirme.

**Karar kuralı:**
- BLOCKER ❌ veya ⚠️ varsa: **NO-GO**.
- BLOCKER ❓ ya da HIGH ❌/⚠️ varsa: **GO (şartlı)**. Şartlar "Önce yapılacaklar" bölümüne yazılır: her BLOCKER ❓ için kimin doğrulayacağı, her HIGH için kapanış tarihi (en geç yayından 1 hafta sonra).
- Diğer durumlarda: **GO**.

### Rapor şablonu
```
## Frontend Launch Readiness — <proje> — <tarih>
**Karar: NO-GO | GO (şartlı) | GO** — <tek cümle>
Özet: BLOCKER x❌ y⚠️ z❓ · HIGH x❌ y⚠️ z❓ · MEDIUM x❌ y⚠️ z❓ · ✅ n · ➖ n

| ID | Madde | Önem | Durum | Kanıt | Düzeltme |
|----|-------|------|-------|-------|----------|
... (F01–F29 eksiksiz)

### ❓ Manuel doğrulanacaklar
### Listede olmayan ek bulgular
### Önce yapılacaklar
```

## Madde listesi
| ID | Önem | Madde |
|---|---|---|
| **Güvenlik** |||
| F01 | BLOCKER | Bundle'da secret yok. `NEXT_PUBLIC_`/`VITE_`/`REACT_APP_` önekli her değişken public kabul edilir. Build çıktısı taranmış. |
| F02 | BLOCKER | Token localStorage/sessionStorage'da değil. httpOnly cookie kullanılıyor ve istekler `credentials: 'include'` ile gidiyor. |
| F03 | BLOCKER | XSS: `dangerouslySetInnerHTML`/`v-html`/`innerHTML` yalnızca DOMPurify'dan geçmiş içerikle kullanılıyor. Kullanıcıdan gelen URL'lerde yalnızca `http(s)` şemasına izin veriliyor (`javascript:` engelli). |
| F04 | HIGH | CSP (nonce veya hash tabanlı) ve güvenlik header'ları (HSTS, nosniff, frame-ancestors, Referrer-Policy) tanımlı. 3. parti script'lerin envanteri tutuluyor. CDN'den yüklenen script'lerde SRI kullanılıyor. |
| F05 | HIGH | Prod'da source map public değil. `console.log` ile veri sızmıyor, debug araçları kapalı. Tüm istekler HTTPS üzerinden, mixed content yok. |
| F06 | HIGH | UI'da yetkiye göre gizleme yalnızca UX içindir. Gerçek kontrol backend'de (B10–B12). |
| F07 | HIGH | Public formlarda spam koruması var: honeypot veya sunucu tarafında doğrulanan CAPTCHA, ayrıca rate limit. |
| **SEO ve paylaşım** |||
| F08 | HIGH | Her sayfanın kendine özgü title (~50–60 karakter) ve description (~150–160 karakter) etiketi var. Canonical ve `<html lang>` tanımlı. Site birden fazla dilde yayındaysa `hreflang` alternatifleri tanımlı. |
| F09 | HIGH | `robots.txt` doğru: prod'da `Disallow: /` yok, gizli yolların listesi yok, sitemap linki var. Staging `noindex` ve şifre korumalı. |
| F10 | MEDIUM | `sitemap.xml` yalnızca index'lenebilir URL'leri içeriyor ve Search Console'a gönderilmiş. |
| F11 | MEDIUM | Open Graph görseli (1200×630, mutlak URL) ve Twitter card tanımlı. |
| F12 | MEDIUM | Favicon (ico/svg), apple-touch-icon ve web manifest var. |
| **Hata ve durum ekranları** |||
| F13 | HIGH | Özel 404 sayfası gerçekten 404 status kodu dönüyor (soft 404 değil). Özel 500 sayfası ve error boundary var. |
| F14 | HIGH | Loading durumları var (skeleton veya spinner). Submit sırasında buton disabled, çift gönderim engelleniyor. |
| F15 | HIGH | Form hataları alanın yanında (inline) ve erişilebilir (`aria-describedby`, `aria-invalid`) gösteriliyor. Hata sonrası kullanıcının girdiği veri kaybolmuyor. Hatalı yanıtta başarı akışı çalışmıyor. Teknik hata metni kullanıcıya gösterilmiyor. |
| F16 | HIGH | Hata takibi (Sentry vb.) kurulu. Source map'ler public değil, yalnızca hata takip aracına yükleniyor. |
| **Hukuk (KVKK + GDPR)** |||
| F17 | BLOCKER | Çerez banner'ında "Reddet" butonu "Kabul" butonu kadar görünür. **Onay alınmadan analytics/marketing script'i yüklenmiyor.** Kullanıcı tercihini sonradan değiştirebiliyor. Consent Mode v2 kullanılıyor. |
| F18 | BLOCKER | Gizlilik politikası (GDPR md. 13 bilgileri dahil), KVKK aydınlatma metni ve çerez politikası mevcut. Açık rıza metni gerekiyorsa o da var. Kişisel veri toplayan her formun yanında aydınlatma metnine link var. |
| F19 | HIGH | Kullanım koşulları var. E-ticaret yapılıyorsa mesafeli satış sözleşmesi, ön bilgilendirme formu ve iade koşulları da var. Hepsine footer'dan erişilebiliyor. |
| F20 | MEDIUM | İletişim bilgileri ve veri sorumlusu kimliği açıkça yazılı (unvan, adres, e-posta). |
| **Analytics** |||
| F21 | HIGH | Analytics consent'e bağlı çalışıyor. URL'lerde ve event'lerde PII yok. Conversion event'leri tanımlı. Placeholder ID kalmamış. |
| **UX ve performans** |||
| F22 | HIGH | Mobil uyumlu: viewport meta etiketi var, sabit genişlik ve yatay scroll yok, dokunma hedefleri ≥44px. |
| F23 | HIGH | Görseller WebP/AVIF formatında, `srcset` ve lazy load kullanılıyor. width/height tanımlı (CLS'ye karşı). LCP görselinde `fetchpriority="high"` var (Next ≤15'te `priority` de olur). Referans verilen tüm görseller gerçekten mevcut. |
| F24 | HIGH | Core Web Vitals: LCP < 2.5 sn, INP < 200 ms, CLS < 0.1. Lighthouse veya PageSpeed ile ölçülmüş. |
| F25 | HIGH | Erişilebilirlik WCAG 2.2 AA temel düzeyde: alt text (dekoratif görselde `alt=""`), her input için `<label>`, kontrast, klavye ile kullanım, görünür focus. |
| F26 | MEDIUM | Çapraz tarayıcı testi yapılmış: Chrome, Safari iOS, Firefox, Samsung Internet. |
| F27 | MEDIUM | *Koşullu (landing):* İlk ekranda CTA var. Mobilde sabit CTA içeriği ve safe-area'yı örtmüyor. |
| F28 | MEDIUM | *Koşullu:* Teşekkür sayfası var ve conversion takibi bu sayfaya bağlı. |
| **Tedarik zinciri** |||
| F29 | HIGH | Framework ve bağımlılıklarda bilinen kritik CVE yok (`npm audit --omit=dev`). Lockfile commit'li. `.env*` dosyaları gitignore'da. |

## Sık yapılan hatalar
| Hata | Gerçek |
|---|---|
| "Banner var, KVKK tamam" | GA/Pixel banner'dan önce yükleniyorsa F17 ❌ olur. Kontrol için script'in yüklenme koşuluna bak. |
| "Key'i env'e koydum" | `NEXT_PUBLIC_`/`VITE_` önekli değişkenler bundle'a gömülür. F01 ❌ olur. Önce rotate et, sonra server'a taşı. |
| "Admin linkini robots.txt'ye Disallow yazdım" | Bu, gizli yolu herkese ilan etmek demektir. Gizleme işi auth ile yapılır (F09, B14). |
| "404 sayfası var" | Status 200 dönüyorsa soft 404 olur, F13 ⚠️. |
| Lighthouse'u çalıştırmadan F24'e ✅ vermek | Ölçüm yoksa durum ❓ olur. |
| Placeholder'ı label yerine kullanmak | F25 ❌. Placeholder yazmaya başlayınca kaybolur ve ekran okuyucu güvenilir biçimde okumaz. |
