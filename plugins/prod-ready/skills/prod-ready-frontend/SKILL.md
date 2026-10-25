---
name: prod-ready-frontend
description: Use when building or reviewing web frontend pages, forms, login UI, layouts, analytics/tracking scripts, cookie banners, privacy pages or SEO setup; and when asked whether a website or web app is ready for production, go-live or launch ("is the site ready to launch", "pre-launch checklist", "launch audit", "GDPR/cookie check", "site yayına hazır mı", "production öncesi frontend kontrolü", "SEO/KVKK kontrolü").
---

# Prod-Ready Frontend

## Overview
A 29-item checklist for a web frontend that is about to go to production. It covers security, SEO, error states, privacy law, analytics, UX and performance. Stack-agnostic.

Two modes:
- **Build mode:** while writing code, the relevant items are the default behavior.
- **Audit mode:** every item is scored with evidence and the report ends with a GO / NO-GO verdict.

Files:
- Item details: [references/checklist.md](references/checklist.md)
- Stack-specific patterns:
  - [references/stack-nextjs.md](references/stack-nextjs.md)
  - [references/stack-spa.md](references/stack-spa.md) (React/Vite/Vue)
- Privacy law by jurisdiction:
  - [references/privacy-eu.md](references/privacy-eu.md) (EU/EEA: GDPR + ePrivacy)
  - [references/privacy-tr.md](references/privacy-tr.md) (Türkiye: KVKK, e-commerce and commercial messaging rules)

Backend security is out of scope here; use the `prod-ready-backend` skill. F06 in this skill relies on backend items B10–B12 for the real authorization check.

## Choosing the mode
- Writing a page, form, layout, script or config → **Build mode**.
- "Is it ready / audit / check / we're launching" → **Audit mode**.

## Build mode
| What you are writing | Items to apply |
|---|---|
| New page | F08, F11, F13, F22, F23, F25 |
| Form | F07, F14, F15, F25; privacy notice link (F18) |
| Login / auth UI | F02, F06, F15 |
| Code rendering user content | F03 |
| Third-party script / analytics / pixel | F04, F17, F21 |
| Env / config / build settings | F01, F05, F09 |
| Landing page | F27, F28 |

If you deliberately deviate from an item, leave a comment: `// launch: <item> skipped because <reason>`.

## Target markets (privacy items F17–F21)
The legal items have a jurisdiction-agnostic core (in the checklist) plus market-specific requirements (in the privacy files).

1. Determine the target markets, in this order of precedence: what the user says → locales (`<html lang>`, i18n config) → currencies → domains (`.com.tr`, `.de`) → existing legal pages.
2. Read the privacy file of every target market and apply all of them. EU/EEA → `privacy-eu.md`. Türkiye → `privacy-tr.md`.
3. If a target market has no file (e.g. US, UK), apply the core rules and add to the ❓ section: "No market-specific guidance for <market>; legal review required." For the UK, `privacy-eu.md` is a reasonable baseline (UK GDPR + PECR), still flagged ❓.
4. If the markets cannot be determined, ask the user once. If you cannot ask, assume the EU baseline and say so in the report.

## Audit mode
1. Detect the stack and read the matching reference file. Determine the target markets and read their privacy files.
2. Read `references/checklist.md`. **Every ID from F01 to F29 must appear as one row in the report.** Skipping an ID leaves the report incomplete.
3. Collect evidence for each item: `file:line`, command output, or a measurement from a live URL.
4. Fill in the report using the template below.

**Statuses:**
- ✅ Pass, with evidence
- ❌ Fail
- ⚠️ Partial
- ➖ N/A (with a reason; e.g. "in-app screen, not a landing page" → F27)
- ❓ Manual: cannot be verified from code. Examples: Lighthouse scores, real-device testing, Search Console, legal adequacy of policy texts.

**No evidence, no ✅.**

**Scoring rules:**
- **Mixed items:** if part of an item is verifiable from code and part is not (e.g. F10: file missing + Search Console), score the worst status among the verifiable parts. Add the unverifiable part to the ❓ section as a question.
- **Framework defaults count as evidence.** Don't give ❌ just because something is not written explicitly. Examples: the Next App Router adds the viewport meta tag itself (F22); Vite's `build.sourcemap` defaults to `false` (F05).
- **F01:** a secret in a prefixed variable is ❌. This rule takes precedence over the build scan. If the project cannot be built, score from source and list the build scan in the ❓ section.
- **F06:** if there is no role-based UI and the frontend does not send role/identity itself, give ➖. If the frontend sends a role in a header, body or query, give ❌. Put backend authorization gaps under "Additional findings" and point to `prod-ready-backend`.
- **F07:** every form usable without logging in is in scope, login included.
- **F13:** if only the framework's default 404 page exists (correct status, but not custom), give ⚠️.
- **F19:** if you see a payment SDK, a `/checkout` or `/orders` endpoint, or a payment provider key, assume e-commerce. If the user says otherwise, ask about the contradiction under ❓.
- **F24 / F26:** with no measurement or test record, the status is always ❓. Put the risks visible in code in the evidence column.
- **F28:** applies only if there is a lead, contact, sign-up or purchase form. Otherwise ➖.
- **F29:** no lockfile → ❌; this takes precedence over the "estimated from versions → ⚠️" rule. If the project is not a git repo, ask about Dependabot and commits under ❓.
- **Tools that cannot run:** if build, `npm audit`, Lighthouse or axe cannot run, score from source and list the command to run in the ❓ section.
- **Secret values:** never print a value in the report. The prefix (`sk-…`) is enough.
- **Scope:** you may read backend code to gather evidence (e.g. cookie settings for F02). Don't elaborate on backend findings; mention them briefly under "Additional findings".

**Language:** write the report in the user's language. If the user's or the environment's instructions forbid emoji, use these status labels: PASS / FAIL / PARTIAL / N/A / MANUAL.

**Severity:**
- BLOCKER: stops the launch.
- HIGH: fixed within the first week.
- MEDIUM: improvement.

**Verdict rule:**
- Any BLOCKER ❌ or ⚠️ → **NO-GO**.
- Any BLOCKER ❓, or any HIGH ❌/⚠️ → **GO (conditional)**. List the conditions under "Fix first": for each BLOCKER ❓ who verifies it, for each HIGH a closing date (no later than one week after launch).
- Otherwise → **GO**.

### Report template
```
## Frontend Launch Readiness — <project> — <date>
**Verdict: NO-GO | GO (conditional) | GO** — <one sentence>
Target markets: <e.g. EU, TR> (source: <user / locales / domain>)
Summary: BLOCKER x❌ y⚠️ z❓ · HIGH x❌ y⚠️ z❓ · MEDIUM x❌ y⚠️ z❓ · ✅ n · ➖ n

| ID | Item | Severity | Status | Evidence | Fix |
|----|------|----------|--------|----------|-----|
... (F01–F29, none missing)

### ❓ To verify manually
### Additional findings (not on the list)
### Fix first
```

## Checklist
| ID | Severity | Item |
|---|---|---|
| **Security** |||
| F01 | BLOCKER | No secrets in the bundle. Every `NEXT_PUBLIC_`/`VITE_`/`REACT_APP_` variable is treated as public. Build output scanned. |
| F02 | BLOCKER | Tokens not in localStorage/sessionStorage. httpOnly cookies, requests sent with `credentials: 'include'`. |
| F03 | BLOCKER | XSS: `dangerouslySetInnerHTML`/`v-html`/`innerHTML` only with DOMPurify-sanitized content. User-supplied URLs allow only `http(s)` (`javascript:` blocked). |
| F04 | HIGH | CSP (nonce- or hash-based) and security headers (HSTS, nosniff, frame-ancestors, Referrer-Policy) in place. Third-party script inventory kept. SRI on CDN scripts. |
| F05 | HIGH | No public source maps in production. No data leaking via `console.log`, debug tools off. Every request over HTTPS, no mixed content. |
| F06 | HIGH | Hiding UI by permission is UX only. The real check is on the backend (B10–B12). |
| F07 | HIGH | Spam protection on public forms: honeypot or server-verified CAPTCHA, plus rate limiting. |
| **SEO and sharing** |||
| F08 | HIGH | Unique title (~50–60 chars) and description (~150–160 chars) per page. Canonical and `<html lang>` set. `hreflang` alternates when the site is multilingual. |
| F09 | HIGH | `robots.txt` correct: no `Disallow: /` in production, no list of hidden paths, sitemap link present. Staging is `noindex` and password-protected. |
| F10 | MEDIUM | `sitemap.xml` lists only indexable URLs and is submitted to Search Console. |
| F11 | MEDIUM | Open Graph image (1200×630, absolute URL) and Twitter card set. |
| F12 | MEDIUM | Favicon (ico/svg), apple-touch-icon and web manifest present. |
| **Error and state screens** |||
| F13 | HIGH | Custom 404 page that really returns 404 (no soft 404). Custom 500 page and error boundary. |
| F14 | HIGH | Loading states (skeleton or spinner). Button disabled while submitting; no double submits. |
| F15 | HIGH | Form errors inline and accessible (`aria-describedby`, `aria-invalid`). User input survives errors. The success path does not run on an error response. No technical error text shown to users. |
| F16 | HIGH | Error tracking (Sentry etc.) installed. Source maps are not public, only uploaded to the error tracker. |
| **Privacy and legal** (see Target markets) |||
| F17 | BLOCKER | No non-essential cookies or tracking before consent where the target markets require consent. Reject is as easy as accept. Choice can be changed later. Google tags use Consent Mode v2. |
| F18 | BLOCKER | The privacy notices each target market requires are published, and every form collecting personal data links to them. Separate opt-in consents where the market requires them. |
| F19 | HIGH | Terms of use exist. For e-commerce, the consumer contract information each target market requires (pre-contract info, withdrawal/returns). All reachable from the footer and checkout. |
| F20 | MEDIUM | Contact details and the identity of the data controller (legal name, address, email, privacy contact) clearly stated, plus any representative the market requires. |
| **Analytics** |||
| F21 | HIGH | Analytics tied to consent. No PII in URLs or events. Conversion events defined. No placeholder IDs left. |
| **UX and performance** |||
| F22 | HIGH | Mobile-friendly: viewport meta present, no fixed widths or horizontal scroll, tap targets ≥44px. |
| F23 | HIGH | Images in WebP/AVIF with `srcset` and lazy loading. width/height set (against CLS). LCP image has `fetchpriority="high"` (Next ≤15 may use `priority`). Every referenced image actually exists. |
| F24 | HIGH | Core Web Vitals: LCP < 2.5 s, INP < 200 ms, CLS < 0.1, measured with Lighthouse or PageSpeed. |
| F25 | HIGH | Accessibility at WCAG 2.2 AA basics: alt text (`alt=""` for decorative images), a `<label>` for every input, contrast, keyboard operability, visible focus. |
| F26 | MEDIUM | Cross-browser testing done: Chrome, iOS Safari, Firefox, Samsung Internet. |
| F27 | MEDIUM | *Conditional (landing):* primary CTA above the fold. A sticky mobile CTA doesn't cover content or the safe area. |
| F28 | MEDIUM | *Conditional:* a thank-you page exists and conversion tracking is tied to it. |
| **Supply chain** |||
| F29 | HIGH | No known critical CVEs in the framework or dependencies (`npm audit --omit=dev`). Lockfile committed. `.env*` files gitignored. |

## Common mistakes
| Mistake | Reality |
|---|---|
| "We have a cookie banner, so we're compliant" | If GA/Pixel loads before the banner is answered, F17 is ❌. Check the condition under which the script loads. |
| "I put the key in env" | `NEXT_PUBLIC_`/`VITE_` variables are embedded in the bundle. F01 is ❌. Rotate first, then move it to the server. |
| "I added the admin URL to robots.txt as Disallow" | That announces the hidden path to everyone. Hiding is done with auth (F09, B14). |
| "We have a 404 page" | If it returns status 200, it is a soft 404: F13 ⚠️. |
| Giving F24 ✅ without running Lighthouse | No measurement means ❓. |
| Using a placeholder instead of a label | F25 ❌. Placeholders disappear when typing starts and screen readers don't read them reliably. |
| Applying only one country's rules to a site sold in several markets | Every target market's privacy file applies. |
