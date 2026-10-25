# Next.js (App Router) implementation notes

Some details here are version-specific. For example, Next 16 renamed `middleware.ts` to `proxy.ts`. Check the version in `package.json`.

## F01 Secrets
- Every `NEXT_PUBLIC_*` variable is embedded in the bundle at build time. Code that uses secrets runs only on the server: a route handler, a server action, or a module marked with `import 'server-only'`.
- To search the build output for secrets:
  ```
  grep -rE "sk_live|sk-|AKIA" .next/static
  ```

## F05 Build hygiene
```js
// next.config.js
module.exports = {
  productionBrowserSourceMaps: false,   // the default; don't set it to true
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
For CSP (F04), use the nonce pattern. Generate a nonce per request in `middleware.ts` (Next ≤15) or `proxy.ts` (Next 16+, `export function proxy`, nodejs runtime only). Write it into the `Content-Security-Policy: script-src 'nonce-…' 'strict-dynamic'` header and the `x-nonce` request header. Next adds the nonce to its own scripts automatically. Follow the official "Content Security Policy" guide for the setup.

## F08 / F11 / F12 Metadata, OG and icons
```tsx
// app/layout.tsx
export const metadata: Metadata = {
  metadataBase: new URL('https://acme.com'),
  title: { default: 'Acme — <value proposition>', template: '%s | Acme' },
  description: 'A 150–160 character description',
  alternates: { canonical: '/', languages: { en: '/en', tr: '/tr' } },   // languages only if multilingual
  openGraph: { type: 'website', siteName: 'Acme', images: ['/og.png'] },   // 1200×630
  twitter: { card: 'summary_large_image' },
};
export default function RootLayout({ children }) {
  return <html lang="en"><body>{children}</body></html>;
}
```
- On dynamic pages, generate title and description from content with `export async function generateMetadata({ params })`.
- File-based metadata works too. Next wires these files up automatically:
  - `app/favicon.ico`
  - `app/icon.png`
  - `app/apple-icon.png`
  - `app/manifest.ts`
  - `app/opengraph-image.png`

## F09 / F10 robots and sitemap (per environment)
```ts
// app/robots.ts
export default function robots(): MetadataRoute.Robots {
  const isProd = process.env.VERCEL_ENV === 'production';   // use your own environment variable
  return isProd
    ? { rules: { userAgent: '*', allow: '/' }, sitemap: 'https://acme.com/sitemap.xml' }
    : { rules: { userAgent: '*', disallow: '/' } };
}
// app/sitemap.ts
export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  return [{ url: 'https://acme.com/', lastModified: new Date() } /* , ...public pages */];
}
```
- If you use these files, delete `public/robots.txt`; the two conflict.
- Never list admin paths in robots.

## F13 404 / 500
- Add `app/not-found.tsx`. When a resource is missing, call `notFound()` (`next/navigation`) from a server component. It returns status 404.
- `app/error.tsx` (`'use client'`) catches segment-level errors. Add `app/global-error.tsx` too, to catch errors in the root layout.
- Don't forget `if (!res.ok) notFound()` after a fetch.

## F03 XSS
```tsx
import DOMPurify from 'isomorphic-dompurify';
<div dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(post.body) }} />
const safeHref = (u: string) => { try { return ['http:', 'https:'].includes(new URL(u).protocol) ? u : undefined; } catch { return undefined; } };
<a href={safeHref(post.authorWebsite)} target="_blank" rel="noopener noreferrer">Author</a>
```

## F17 / F21 Consent-gated analytics
```tsx
'use client';
// consent state comes from your CMP or your own banner
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
- When consent is given, call `gtag('consent','update',{analytics_storage:'granted', ...})`.
- The `GoogleAnalytics` component from `@next/third-parties` must likewise render only after consent.

## F23 Images
- Use `next/image`. It produces WebP/AVIF and `srcset`. Pass `width` and `height`, or use `fill` + `sizes`.
- For the LCP image, use `priority` on Next ≤15. On Next 16+, `priority` is deprecated; the docs recommend `fetchPriority="high"` or `loading="eager"` in most cases (a `preload` prop also exists).

## F14 / F15 Forms
- With server actions, return per-field errors via `useActionState`. Disable the button while submitting with `useFormStatus().pending`.
- Validate on the server with zod. Client-side validation is UX only.
