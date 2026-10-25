# SPA (React/Vue + Vite, CRA) uygulama notları

## F01 Env değişkenleri
- `VITE_*` önekli değişkenler `import.meta.env` ile okunur. CRA'da `REACT_APP_*` önekli değişkenler bundle'a gömülür. Bu önekli değişkenlerin hepsini public kabul et.
- Secret gerektiren çağrılar backend veya BFF üzerinden yapılmalı. Bir SPA'da gizli tutulabilecek bir yer yoktur.
- Build sonrası kontrol: `grep -rE "sk_live|sk-|AKIA" dist`

## F05 Source map
- Vite'ta `build.sourcemap` varsayılan olarak `false`'tur.
- Hata takibi (F16) için source map gerekiyorsa `sourcemap: 'hidden'` ayarını kullan. Üretilen map dosyalarını Sentry'ye yükle, ardından deploy etmeden önce `dist/**/*.map` dosyalarını sil.

## Header'lar (F04, F05)
SPA kendi header'ını üretmez, header'lar hosting tarafında tanımlanır:
- **Netlify:** `public/_headers`
- **Vercel:** `vercel.json` içinde `headers` alanı
- **nginx:** `add_header ... always;`

Tanımlanması gerekenler: CSP, HSTS, nosniff, `X-Frame-Options`/`frame-ancestors`, Referrer-Policy.

## F08 / F11 Meta
- **React:** `react-helmet-async`
- **Vue:** `@unhead/vue` (`useHead`)

Bu araçlar title, description ve OG etiketlerini sayfa bazında yönetir.

Önemli bir uyarı: sosyal medya crawler'ları ve bazı arama motorları JS çalıştırmaz. Landing veya pazarlama sayfaları SEO açısından önemliyse bunları **SSG veya prerender** ile üret (vite-ssg, prerender plugin) ya da o kısmı SSR yapan bir framework'e taşı.

## F09 / F10 robots ve sitemap
- `public/robots.txt` dosyası olduğu gibi kopyalanır. Ortama göre farklı içerik gerekiyorsa build script'inde üret, ya da staging'de hosting üzerinden `X-Robots-Tag: noindex` header'ı ekle.
- Sitemap'i build sırasında route listesinden üret.

## F13 404
- SPA hosting'leri genelde tüm yolları `index.html`'e yönlendirir ve 200 döner. Bu bir soft 404'tür.
- Client tarafında bir catch-all route ile 404 bileşeni göster. Bu ⚠️ seviyesinde iyileştirmedir.
- Gerçek bir 404 status kodu için iki yol var:
  - Bilinen route'ları prerender edip geri kalanını hosting'in 404 kuralına bırak.
  - SEO açısından önemli sayfaları SSG ile üret.
- Error boundary için:
  - React: `react-error-boundary` kullan.
  - Vue: `app.config.errorHandler` ayarla ve bir hata sayfası göster.

## F02 Auth
- İsteklerde `fetch(url, { credentials: 'include' })` veya axios'ta `withCredentials: true` kullan.
- Backend tarafında CORS allowlist'i ve CSRF koruması olmalı (B21, B22).
- Token'ı store'a, localStorage'a veya sessionStorage'a koyma.

## F23 Görseller
- Görselleri build öncesinde optimize et, örneğin `vite-imagetools` veya sharp script'i ile.
- `<img>` etiketlerinde şu attribute'lar olsun: `width`, `height`, `loading="lazy"`, `decoding="async"`, `srcset`/`sizes`.
- LCP görselinde `fetchpriority="high"` kullan ve bu görsele lazy loading verme.

## F17 / F21 Analytics
- GA veya GTM script'ini `index.html`'e sabit olarak koyma. Onay verildikten sonra script'i dinamik olarak ekle:
  ```js
  document.head.appendChild(Object.assign(document.createElement('script'), { src, async: true }))
  ```
- Consent Mode v2'nin `default: denied` ayarı her durumda en başta çalışmalı.
