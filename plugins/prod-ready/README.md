# prod-ready

Production'a çıkmadan önce backend ve web frontend için kontrol listeleri. Kod yazarken kuralları uygular, istendiğinde projeyi denetleyip kanıta dayalı bir **GO / NO-GO** raporu üretir.

*Production readiness checklists for backend and web frontend. Applies the rules while you code and produces an evidence-based GO / NO-GO audit report on request.*

## İçerik

| Skill | Kapsam |
|---|---|
| `prod-ready-backend` | 39 madde, 12 alanda: kimlik doğrulama, yetkilendirme/IDOR, injection ve SSRF, CSRF/CORS/HTTPS/header'lar, rate limit, dosya yükleme, secret yönetimi, hata ve audit log, veritabanı/BaaS, backup, tedarik zinciri/CI, operasyon/KVKK. Stack notları: ASP.NET Core, Node.js (Express/NestJS/Next route handlers). |
| `prod-ready-frontend` | 29 madde: güvenlik (bundle secret, XSS, CSP), SEO (meta, robots, sitemap, OG), 404/500 ve loading/form hataları, KVKK/GDPR (çerez onayı, aydınlatma metni), analytics, mobil, görseller, Core Web Vitals, erişilebilirlik, bağımlılık CVE'leri. Stack notları: Next.js App Router, React/Vue SPA. |

Her maddenin bir ID'si (B01–B39, F01–F29) ve önem derecesi (BLOCKER / HIGH / MEDIUM) vardır.

## Kullanım

Skill'ler otomatik tetiklenir; ayrıca adıyla da çağırabilirsin.

- **Build modu** — auth, endpoint, form, upload, sayfa yazarken ilgili maddeler varsayılan davranış olur.
  > "Express için login endpoint'i yaz"
- **Audit modu** — her madde ✅ / ❌ / ⚠️ / ➖ / ❓ ile, `dosya:satır` kanıtıyla puanlanır. Koddan doğrulanamayanlar (backup restore testi, altyapı MFA'sı, DB ağ erişimi, Lighthouse) "manuel doğrula" sorusu olarak ayrılır. Herhangi bir BLOCKER kalırsa karar NO-GO'dur.
  > "Bu proje prod'a hazır mı?" · "Frontend'i yayın öncesi denetle"

Rapor, kullanıcının yazdığı dilde üretilir.

## Kurulum

```bash
claude plugin marketplace add <bu-reponun-git-url'si-veya-yerel-yolu>
claude plugin install prod-ready@prod-ready-marketplace
```

Kurulumdan sonra yeni bir oturum aç. Daha önce aynı skill'leri `~/.claude/skills/` altına elle kopyaladıysan çift görünmemesi için onları kaldır.

## Sınırlar

- Bu bir kontrol listesidir; sızma testi, SAST/DAST aracı veya hukuki görüş yerine geçmez.
- KVKK/GDPR metinlerinin hukuki yeterliliği her zaman "manuel doğrula" olarak hukuk ekibine bırakılır.
- Kod örnekleri desen gösterir; projenin sürümüne göre doğrulanmalıdır.

## Geliştirme

`evals/` altındaki vaka, kasıtlı açıklar içeren örnek bir uygulamada audit modunu test eder:

```bash
claude plugin eval plugins/prod-ready
```

Değişiklikler için [CHANGELOG.md](CHANGELOG.md).
