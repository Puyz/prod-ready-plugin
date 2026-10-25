# SPA (React/Vue + Vite, CRA) implementation notes

## F01 Environment variables
- `VITE_*` variables are read via `import.meta.env`; in CRA, `REACT_APP_*` variables are embedded in the bundle. Treat all of these prefixed variables as public.
- Calls that need secrets go through the backend or a BFF. An SPA has no place to keep a secret.
- Check after building: `grep -rE "sk_live|sk-|AKIA" dist`

## F05 Source maps
- Vite's `build.sourcemap` defaults to `false`.
- If error tracking (F16) needs source maps, use `sourcemap: 'hidden'`. Upload the generated maps to Sentry, then delete `dist/**/*.map` before deploying.

## Headers (F04, F05)
An SPA does not produce its own headers; they are set at the host:
- **Netlify:** `public/_headers`
- **Vercel:** the `headers` field in `vercel.json`
- **nginx:** `add_header ... always;`

Set: CSP, HSTS, nosniff, `X-Frame-Options`/`frame-ancestors`, Referrer-Policy.

## F08 / F11 Meta
- **React:** `react-helmet-async`
- **Vue:** `@unhead/vue` (`useHead`)

These manage title, description and OG tags per page.

An important caveat: social-media crawlers and some search engines don't run JS. If landing or marketing pages matter for SEO, generate them with **SSG or prerendering** (vite-ssg, a prerender plugin), or move that part to a framework with SSR.

## F09 / F10 robots and sitemap
- `public/robots.txt` is copied as-is. If content must differ per environment, generate it in the build script, or add an `X-Robots-Tag: noindex` header on staging at the host.
- Generate the sitemap from the route list at build time.

## F13 404
- SPA hosts usually rewrite every path to `index.html` with status 200. That is a soft 404.
- Showing a 404 component via a client-side catch-all route is a ⚠️-level improvement.
- Two ways to get a real 404 status:
  - Prerender known routes and leave the rest to the host's 404 rule.
  - Generate SEO-relevant pages with SSG.
- Error boundaries:
  - React: `react-error-boundary`.
  - Vue: set `app.config.errorHandler` and show an error page.

## F02 Auth
- Use `fetch(url, { credentials: 'include' })` or `withCredentials: true` in axios.
- The backend must have a CORS allowlist and CSRF protection (B21, B22).
- Don't put tokens in a store, localStorage or sessionStorage.

## F23 Images
- Optimize images before the build, e.g. with `vite-imagetools` or a sharp script.
- `<img>` tags should have: `width`, `height`, `loading="lazy"`, `decoding="async"`, `srcset`/`sizes`.
- Use `fetchpriority="high"` on the LCP image and don't lazy-load it.

## F17 / F21 Analytics
- Don't hard-code the GA or GTM script in `index.html`. Inject it dynamically after consent:
  ```js
  document.head.appendChild(Object.assign(document.createElement('script'), { src, async: true }))
  ```
- The Consent Mode v2 `default: denied` call must always run first.
