# Next.js (App Router) uygulama notları

Bu dosyada sürüme bağlı ayrıntılar var. Örneğin Next 16'da `middleware.ts` dosyasının adı `proxy.ts` oldu. Projede kullanılan sürümü `package.json` dosyasından kontrol et.

## F01 Secret
- `NEXT_PUBLIC_*` önekli her değişken build sırasında bundle'a gömülür. Secret kullanan kod yalnızca sunucuda çalışmalı: route handler, server action ya da `import 'server-only'` ile işaretlenmiş bir modül.
- Build çıktısında secret aramak için:
  ```
  grep -rE "sk_live|sk-|AKIA" .next/static
  ```

## F05 Build hijyeni
```js
// next.config.js
module.exports = {
  productionBrowserSourceMaps: false,   // varsayılan değer; true yapma
  poweredByHeader: false,
  compiler: { removeConsole: { exclude: ['error'] } },
  async headers() {
    return [{ source: '/(.*)', headers: [
      { key: 'Strict-Transport-Security', value: 'max-age=31536000; includeSubDomains' },
      { key: 'X-Content-Type-Options', value: 'nosniff' },
      { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
      { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=()' },
      { key: 'X-Frame-Options', value: 'DENY' },
    ] }];
  },
};
```
CSP (F04) için nonce tabanlı desen kullan. Next ≤15'te `middleware.ts`, Next 16+'da `proxy.ts` dosyasında (`export function proxy`, yalnızca nodejs runtime) her istek için bir nonce üret. Bu nonce'u `Content-Security-Policy: script-src 'nonce-…' 'strict-dynamic'` header'ına ve `x-nonce` request header'ına yaz. Next kendi script'lerine nonce'u otomatik ekler. Kurulum için resmi "Content Security Policy" rehberini izle.

## F08 / F11 / F12 Metadata, OG ve ikonlar
```tsx
// app/layout.tsx
export const metadata: Metadata = {
  metadataBase: new URL('https://acme.com.tr'),
  title: { default: 'Acme — <değer önerisi>', template: '%s | Acme' },
  description: '150–160 karakterlik açıklama',
  alternates: { canonical: '/' },
  openGraph: { type: 'website', siteName: 'Acme', images: ['/og.png'] },   // 1200×630
  twitter: { card: 'summary_large_image' },
};
export default function RootLayout({ children }) {
  return <html lang="tr"><body>{children}</body></html>;
}
```
- Dinamik sayfalarda `export async function generateMetadata({ params })` ile içerikten title ve description üret.
- Dosya bazlı metadata kullanılabilir. Next şu dosyaları otomatik bağlar:
  - `app/favicon.ico`
  - `app/icon.png`
  - `app/apple-icon.png`
  - `app/manifest.ts`
  - `app/opengraph-image.png`

## F09 / F10 robots ve sitemap (ortama göre)
```ts
// app/robots.ts
export default function robots(): MetadataRoute.Robots {
  const isProd = process.env.VERCEL_ENV === 'production';   // kendi ortam değişkenini kullan
  return isProd
    ? { rules: { userAgent: '*', allow: '/' }, sitemap: 'https://acme.com.tr/sitemap.xml' }
    : { rules: { userAgent: '*', disallow: '/' } };
}
// app/sitemap.ts
export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  return [{ url: 'https://acme.com.tr/', lastModified: new Date() } /* , ...public sayfalar */];
}
```
- Bu dosyaları kullanıyorsan `public/robots.txt` dosyasını sil, ikisi çakışır.
- Admin yollarını robots'a yazma.

## F13 404 / 500
- `app/not-found.tsx` ekle. Kaynak bulunamadığında server component içinden `notFound()` çağır (`next/navigation`). Bu çağrı 404 status kodu döndürür.
- `app/error.tsx` (`'use client'`) segment seviyesindeki hataları yakalar. Root layout'taki hataları yakalamak için ayrıca `app/global-error.tsx` ekle.
- Fetch yaparken `if (!res.ok) notFound()` kontrolünü unutma.

## F03 XSS
```tsx
import DOMPurify from 'isomorphic-dompurify';
<div dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(post.body) }} />
const safeHref = (u: string) => { try { return ['http:', 'https:'].includes(new URL(u).protocol) ? u : undefined; } catch { return undefined; } };
<a href={safeHref(post.authorWebsite)} target="_blank" rel="noopener noreferrer">Yazar</a>
```

## F17 / F21 Onaya bağlı analytics
```tsx
'use client';
// Consent state'i CMP'den veya kendi banner'ından gelir
export function Analytics({ consent }: { consent: boolean }) {
  return (
    <>
      <Script id="consent-default" strategy="beforeInteractive">{`
        window.dataLayer=window.dataLayer||[];function gtag(){dataLayer.push(arguments)}
        gtag('consent','default',{ad_storage:'denied',analytics_storage:'denied',ad_user_data:'denied',ad_personalization:'denied'});`}
      </Script>
      {consent && <Script src={`https://www.googletagmanager.com/gtag/js?id=${process.env.NEXT_PUBLIC_GA_ID}`} strategy="afterInteractive" />}
    </>
  );
}
```
- Onay verildiğinde şu çağrıyı yap: `gtag('consent','update',{analytics_storage:'granted', ...})`
- `@next/third-parties` içindeki `GoogleAnalytics` bileşeni de aynı şekilde yalnızca onaydan sonra render edilmeli.

## F23 Görseller
- `next/image` kullan. Bileşen WebP/AVIF ve `srcset` üretir. `width` ve `height` ver ya da `fill` + `sizes` kullan.
- LCP görselinde Next ≤15 için `priority` kullan. Next 16+'da `priority` deprecated oldu; docs çoğu durumda `fetchPriority="high"` veya `loading="eager"` kullanmayı öneriyor (`preload` prop'u da var).

## F14 / F15 Formlar
- Server action kullanıyorsan `useActionState` ile hataları alan bazında döndür. Gönderim sırasında butonu `useFormStatus().pending` ile disable et.
- Sunucu tarafında zod ile doğrula. Client tarafındaki doğrulama yalnızca UX içindir.
