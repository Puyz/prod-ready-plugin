# Frontend checklist — details

Each item has **Verify**, **Pass** and **Pitfall** parts. Grep results are only a starting point; read every match.

## Security

### F01 — Secrets in the bundle (BLOCKER)
- **Verify:**
  - Find variables prefixed `NEXT_PUBLIC_|VITE_|REACT_APP_|EXPO_PUBLIC_` in `.env*` files and code. For each one ask: "would it matter if everyone saw this value?"
  - Scan the build output: `grep -rE "sk_live|sk-|AKIA|secret|private_key" .next/static dist build`
- **Scoring:** a secret in a prefixed variable is ❌ even if the value is not in the bundle right now. The prefix declares that the value may enter client code, and a single client import is enough to leak it. The build scan confirms an actual leak. `.gitignore` is checked under F29.
- **Pass:** public variables hold only public values: publishable keys, public API URLs, analytics IDs. Calls that need secrets run on the server (route handler or BFF).
- **Pitfall:** moving a leaked key out of env is not enough. It has already shipped in the bundle; **rotate** it first.

### F02 — Token storage (BLOCKER)
- **Verify:** search for `localStorage|sessionStorage` together with `token|jwt|auth`. Do axios or fetch interceptors add `Authorization: Bearer`?
- **Pass:** auth travels in an httpOnly cookie and requests use `credentials: 'include'`. JS never sees the token. State-changing requests send the CSRF token or custom header the backend expects (B21).

### F03 — XSS (BLOCKER)
- **Verify:** search for `dangerouslySetInnerHTML|v-html|innerHTML|outerHTML|insertAdjacentHTML|document.write|eval\(`. Check how user-supplied values reach `href`/`src` attributes.
- **Pass:** `DOMPurify.sanitize` runs before HTML is rendered. URLs are checked with `new URL(u).protocol` to be `http:` or `https:`. User data never reaches `eval` or string-form `setTimeout`.

### F04 — CSP, security headers and third-party code (HIGH)
- **Pass:**
  - A CSP header exists. `script-src` uses nonces or hashes; no `'unsafe-inline'`.
  - `frame-ancestors` set.
  - HSTS, `X-Content-Type-Options: nosniff` and `Referrer-Policy` returned. These may be set in app config or at the host.
  - A list of loaded third-party scripts and what each one does.
  - `integrity` (SRI) on pinned CDN scripts.
- **Scoring:**
  - CSP present but containing `'unsafe-inline'` or `*` → ⚠️.
  - Headers configured at the host and not visible in code → ❓.
  - A missing `rel="noopener"` alone is not a reason for ⚠️; modern browsers apply it by default. Mention it in the fix column.

### F05 — Build hygiene (HIGH)
- **Verify:**
  - Are `productionBrowserSourceMaps` or `build.sourcemap: true` enabled? Are `.map` files served publicly?
  - Does `console.log` print tokens or user data?
  - Any API or asset URLs starting with `http://`?
- **Pass:** source maps are either not produced or sent only to the error tracker (F16). Nothing is written to the console in production. Every request goes over HTTPS.

### F06 — Permission-based UI hiding (HIGH)
- **Pass:** hiding an admin button is UX only. Every action has a backend authorization check (B10–B12). A role held on the client is never used for a security decision.

### F07 — Spam and bots (HIGH)
- **Pass:** forms usable without logging in (login, sign-up, contact, comments, newsletter) have a honeypot field or CAPTCHA (Turnstile, reCAPTCHA, hCaptcha). Showing a CAPTCHA on login only after a few failed attempts is acceptable. The CAPTCHA token is verified **on the server**. The endpoint is rate-limited.

## SEO and sharing

### F08 — Meta (HIGH)
- **Verify:**
  - Does every route have a title and description? Do they differ from page to page? Are dynamic pages (`/post/[id]`) generated from content?
  - Is `<html lang="...">` set?
  - Is `rel=canonical` present?
- **Pass:** title ~50–60 chars, description ~150–160 chars. Titles include the brand and don't repeat each other. Canonical and lang set. On multilingual sites every language version is linked with `hreflang` (`alternates.languages` in Next).

### F09 — robots.txt (HIGH)
- **Pass:**
  - No `Disallow: /` in production.
  - No admin or hidden paths listed (listing them announces them).
  - A `Sitemap: https://.../sitemap.xml` line.
  - Staging and preview environments send `X-Robots-Tag: noindex` and sit behind basic auth.
- **Pitfall:** the staging `Disallow: /` file gets copied to production. Generate it per environment.

### F10 — sitemap.xml (MEDIUM)
- **Pass:** lists only canonical, indexable URLs that return 200. Login, admin and thank-you pages are excluded. Submitted to Search Console (submission asked as ❓).

### F11 — Open Graph (MEDIUM)
- **Pass:** `og:title`, `og:description`, `og:image` (1200×630, absolute HTTPS URL), `og:url` and `twitter:card=summary_large_image` set.

### F12 — Icons (MEDIUM)
- **Pass:** `favicon.ico` or svg, `apple-touch-icon` (180×180) and `manifest.webmanifest` present.

## Error and state screens

### F13 — 404/500 (HIGH)
- **Verify:** is there a custom 404 page? Does an unknown route really return status 404? SPA hosts often rewrite every path to `index.html` with 200; that is a soft 404. Is there a 500 page and an error boundary?
- **Pass:** a branded 404 page links to the home page and search, with status 404. A custom 500 page exists. Component errors never produce a blank white screen.

### F14 — Loading (HIGH)
- **Pass:** every data-fetching screen has a skeleton or spinner. While submitting, the button is disabled and shows text such as "Sending…". Long operations have cancel or timeout.

### F15 — Form errors (HIGH)
- **Pass:**
  - The error message appears next to the field and is linked with `aria-describedby`. The field is marked `aria-invalid`. Focus moves to the first invalid field.
  - User input is preserved on server errors.
  - `res.ok` is checked. On error, the success path (redirect, storing a token, etc.) does not run.
  - No `alert()`.
  - Users see a clear message, not technical error text.
  - Inputs have the right `type`, `autocomplete` and `inputmode`.

### F16 — Error tracking (HIGH)
- **Pass:** Sentry or similar installed. Releases tagged and source maps uploaded. PII scrubbing on. Alert rules defined.

## Privacy and legal

The items below are the jurisdiction-agnostic core. For each target market, also apply the market file (`privacy-eu.md`, `privacy-tr.md`); see "Target markets" in SKILL.md.

### F17 — Consent before tracking (BLOCKER)
- **Verify:** where and under what condition do scripts such as GA, GTM, Meta Pixel, Hotjar or Clarity load? Do network requests go out before consent? Check the Network and Cookies tabs in DevTools on first load.
- **Pass (core):**
  - On the first visit, only strictly necessary cookies are set, wherever a target market requires prior consent (the EU and Türkiye both do).
  - The banner offers accept, reject and preferences with equal weight. No pre-ticked boxes.
  - The choice is stored and can be changed via a "Cookie settings" link in the footer.
  - Google tags run with Consent Mode v2, defaulting to `denied`.
- **Pitfall:** "By using this site you accept cookies" is not valid consent.

### F18 — Privacy notices (BLOCKER)
- **Pass (core):**
  - A privacy policy / notice exists that covers what each target market requires (see the market files).
  - A cookie policy exists.
  - Every form that collects personal data links to the notice at the point of collection.
  - Consents the market requires to be separate (marketing, cross-border transfer, commercial messages) are **separate, optional** checkboxes, never bundled with the terms.
- **Note:** the legal adequacy of the text is ❓ and goes to the legal team.

### F19 — Terms and consumer contract information (HIGH)
- **Pass:** a terms-of-use page exists. For e-commerce, the pre-contract information, withdrawal/return rules and any mandatory contract documents of each target market (see the market files) exist and are reachable from the footer and the checkout step.

### F20 — Contact and data controller (MEDIUM)
- **Pass:** legal entity name, address, email or phone, and the privacy contact / data-subject request channel are clearly stated, plus any representative a market requires (e.g. an EU representative under GDPR Art. 27).

## Analytics

### F21 — Analytics (HIGH)
- **Pass:**
  - Analytics loads only after consent (F17).
  - No PII such as email, phone or names in URLs or event parameters.
  - A real measurement ID (not a placeholder like `G-XXXX`).
  - Core conversion events defined (form submit, sign-up, purchase).
  - Staging traffic does not mix into production data.

## UX and performance

### F22 — Mobile (HIGH)
- **Verify:** is `<meta name="viewport" content="width=device-width, initial-scale=1">` present? Are there fixed pixel widths such as `width: 1200`? Is there horizontal scrolling at 375px?
- **Pass:** fluid layout. Tap targets at least 44×44px. Input font-size at least 16px (so iOS doesn't auto-zoom).

### F23 — Images (HIGH)
- **Pass:**
  - Images in WebP or AVIF, served responsively with `srcset`/`sizes`. `next/image` in Next.js.
  - `width` and `height` set (otherwise CLS).
  - Below-the-fold images lazy-loaded. The LCP image has `fetchpriority="high"` (Next ≤15 may use `priority`) and is not lazy-loaded.
  - Every file referenced in code actually exists.

### F24 — Core Web Vitals (HIGH)
- **Verify:**
  - With a live or preview URL, measure with PageSpeed Insights or `npx lighthouse <url> --preset=desktop`. Measure the mobile profile too.
  - Without a URL, mark ❓. Look for heavy bundles and render-blocking scripts in code.
- **Pass:** on the mobile profile LCP < 2.5 s, INP < 200 ms, CLS < 0.1.

### F25 — Accessibility (HIGH)
- **Pass:**
  - `<img>` tags have `alt`. Decorative images use `alt=""`.
  - Every input is associated with a `<label>`. A placeholder alone is not enough.
  - Normal text has a contrast ratio of at least 4.5:1.
  - Everything is keyboard-operable with visible focus.
  - Semantic heading order with a single `h1` per page.
- **Verify:** run `npx @axe-core/cli <url>` when possible.

### F26 — Cross-browser (MEDIUM)
- Marked ❓; ask which device/browser combinations were tested.

### F27 — CTA (MEDIUM, conditional)
- **Pass:** landing pages have one clear primary CTA above the fold. A sticky mobile CTA doesn't cover content, the cookie banner or `env(safe-area-inset-bottom)`.
- **When ➖:** in-app screens.

### F28 — Thank-you page (MEDIUM, conditional)
- **Pass:** after a form is submitted, the user is redirected to a separate URL and conversion is tied to it. The page is `noindex` and not in the sitemap.

## Supply chain

### F29 — Dependency and framework CVEs (HIGH)
- **Verify:**
  - Run `npm audit --omit=dev` (if network access exists).
  - Compare the framework version against known critical vulnerabilities. Example: Next.js before 14.2.25 / 15.2.3 is affected by the CVE-2025-29927 middleware bypass.
  - Is there a lockfile?
  - Does `.gitignore` cover `.env*`?
- **Pass:** no unresolved critical or high CVEs. Lockfile committed. Dependabot or Renovate enabled.
- **Scoring:** no lockfile → ❌. If the command could not run and you estimated from versions, give ⚠️ and say "not verified".
