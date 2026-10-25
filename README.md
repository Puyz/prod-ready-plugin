# prod-ready

**prod-ready** gives your coding agent a production-readiness checklist it actually follows: 39 backend items and 29 web frontend items covering security, privacy law, SEO, accessibility and operations. The agent applies them while it writes code, and when you ask whether a project is ready to ship, it audits the codebase and returns an evidence-based **GO / NO-GO** report.

![version](https://img.shields.io/badge/version-1.1.0-blue) ![license](https://img.shields.io/badge/license-MIT-green) ![Claude Code](https://img.shields.io/badge/Claude%20Code-plugin-orange)

## Table of Contents

- [How it works](#how-it-works)
- [Installation](#installation)
- [Using it](#using-it)
- [What a report looks like](#what-a-report-looks-like)
- [What's inside](#whats-inside)
- [Privacy law by market](#privacy-law-by-market)
- [How it's tested](#how-its-tested)
- [Limits](#limits)
- [Updating](#updating)
- [Contributing](#contributing)
- [License](#license)

## How it works

Most launch checklists live in a wiki and get read once. prod-ready puts the checklist where the code is written.

**While you build,** the skills trigger on their own. Ask your agent for a login endpoint and you get Argon2id hashing, httpOnly cookies, per-IP and per-account rate limits, generic error messages and server-side session revocation, without asking for any of them. Ask for a page and it comes with metadata, a real 404, accessible form errors and consent-gated analytics.

**Before you launch,** ask "is this production ready?" The agent works through every item, B01–B39 for the backend and F01–F29 for the frontend, and scores each one with `file:line` evidence:

- No evidence, no pass. "Probably fine" is scored as *verify manually*, never as passed.
- Things code can't prove, such as whether backups have ever been restored, whether admins use MFA or whether the database is reachable from the internet, become questions for the owner instead of guesses.
- Any open BLOCKER means **NO-GO**. Open HIGH items make it a conditional GO with a deadline.
- The fix list is ordered the way an incident responder would order it: rotate leaked secrets, then close what an anonymous attacker can exploit, then what a logged-in user can exploit, then everything else.

Reports are written in the language you ask in.

## Installation

prod-ready is a [Claude Code](https://claude.com/claude-code) plugin. It works in the Claude Code CLI, desktop app and IDE extensions.

**Inside a Claude Code session:**

```text
/plugin marketplace add Puyz/prod-ready-plugin
/plugin install prod-ready@prod-ready-marketplace
```

**From a terminal:**

```bash
claude plugin marketplace add Puyz/prod-ready-plugin
claude plugin install prod-ready@prod-ready-marketplace
```

Start a new session after installing. The skills appear as `prod-ready:prod-ready-backend` and `prod-ready:prod-ready-frontend`.

**Other agents** that read the Agent Skills format (a folder with a `SKILL.md`) can use the folders under [`plugins/prod-ready/skills/`](plugins/prod-ready/skills/) directly. Only Claude Code is tested.

## Using it

You don't need special commands. Talk to your agent as usual.

**Build mode** triggers when you write code the checklist covers:

> Write a login, refresh and logout flow for our Express + Postgres API.
>
> Add a contact form to the landing page.
>
> Add an avatar upload endpoint.

**Audit mode** triggers when you ask about readiness:

> Is this backend ready for production?
>
> We launch next week for customers in the EU. Audit the frontend.
>
> Run a pre-launch security check on the api/ folder.

To be explicit, name the skill: *"Use prod-ready-backend to audit this repo."*

Every audit is read-only. The agent never prints secret values; it reports only prefixes such as `sk_live_…`.

## What a report looks like

An excerpt from a real run against the intentionally broken sample app in this repo's eval suite:

```markdown
## Frontend Launch Readiness — sample-app/web — 2026-10-25

**Verdict: NO-GO.** All five BLOCKER items fail, so this frontend isn't ready for an EU launch
next week. The biggest problems are an API key exposed to the browser, login tokens stored in
`localStorage`, unsanitized HTML on post pages, Google Analytics loading before cookie consent,
and no privacy notice.

Target markets: EU (you told me)
Summary: BLOCKER 5❌ 0⚠️ 0❓ · HIGH 15❌ 0⚠️ 1❓ · MEDIUM 5❌ 0⚠️ 1❓ · ✅ 0 · ➖ 2

| ID  | Item                    | Severity | Status | Evidence                                                   | Fix                                     |
|-----|-------------------------|----------|--------|------------------------------------------------------------|-----------------------------------------|
| F01 | Secrets in bundle       | BLOCKER  | ❌     | `.env.local:2` has `NEXT_PUBLIC_OPENAI_KEY` (`sk-proj-…`)  | Rotate the key first, move it server-side |
| F17 | Consent before tracking | BLOCKER  | ❌     | `layout.tsx:7-8` loads gtag with no consent check          | Consent Mode v2 default `denied`, load GA after consent |
| F24 | Core Web Vitals         | HIGH     | ❓     | Not measured; hero image has no dimensions (CLS risk)      | Run Lighthouse on the mobile profile    |
...
```

Every report also has a *verify manually* section with questions for the owner, an *additional findings* section for problems outside the checklist, and a prioritized *fix first* list.

**Statuses:** ✅ pass · ❌ fail · ⚠️ partial · ➖ not applicable (with a reason) · ❓ verify manually

## What's inside

### `prod-ready-backend` — 39 items

| Area | Items |
|---|---|
| Authentication | Password hashing, token storage, token lifetime and refresh rotation, server-side revocation, JWT validation, brute-force limits, user enumeration, password reset, MFA |
| Authorization | Deny by default, IDOR / ownership checks, identity from the session only, mass assignment, admin panel |
| Input and injection | Server-side validation, SQL injection, command/NoSQL/path injection, SSRF, deserialization, stored HTML |
| Browser and transport | CSRF, CORS, HTTPS/HSTS, security headers, cookie flags |
| Abuse | Rate limits, real client IP behind proxies, body and pagination caps, timeouts |
| Files | Upload validation, random names, private storage, signed URLs |
| Secrets | `.env` hygiene, secret managers, git history, rotation |
| Errors and logging | Global exception handling, production config, audit logs |
| Database | Network exposure, least privilege, TLS, Supabase/Firebase rules, encryption, migrations |
| Backup | Encrypted off-site backups, tested restores, RPO/RTO |
| Supply chain and CI | Dependency CVEs, lockfiles, SAST, secret and container scanning, branch protection |
| Operations and privacy | Health endpoints, monitoring, data subject rights, retention, transfers |

**Stack references:**
- **ASP.NET Core:** a complete reference `Program.cs` that compiles on .NET 8 and .NET 10 with zero warnings, plus .NET 9/10 differences.
- **Node.js:** Express, NestJS and Next.js route handlers.

### `prod-ready-frontend` — 29 items

| Area | Items |
|---|---|
| Security | Secrets in the bundle, token storage, XSS, CSP and headers, source maps, UI-only authorization, form spam |
| SEO and sharing | Titles, descriptions, canonical, `hreflang`, robots.txt, sitemap, Open Graph, icons |
| Error and state screens | Real 404s, 500 pages and error boundaries, loading states, accessible form errors, error tracking |
| Privacy and legal | Consent before tracking, privacy notices, terms and consumer contract info, controller identity |
| Analytics | Consent gating, no PII in events, conversion tracking |
| UX and performance | Mobile layout, image optimization, Core Web Vitals, WCAG 2.2 AA basics, cross-browser testing, CTAs |
| Supply chain | Framework CVEs, lockfiles |

**Stack references:** Next.js App Router (including the Next 15 → 16 changes) and React/Vue single-page apps.

## Privacy law by market

The privacy items have a jurisdiction-neutral core. Market-specific rules live in separate modules:

| Market | Module | Covers |
|---|---|---|
| EU / EEA | [`privacy-eu.md`](plugins/prod-ready/skills/prod-ready-frontend/references/privacy-eu.md) | GDPR (Art. 13 notices, Art. 27 representative, transfers, breach notification), ePrivacy cookie consent, Consumer Rights Directive, European Accessibility Act |
| Türkiye | [`privacy-tr.md`](plugins/prod-ready/skills/prod-ready-frontend/references/privacy-tr.md) | KVKK (information notice, explicit consent, 2024 cross-border transfer rules, VERBİS), commercial messaging (İYS), distance sales |

During an audit the agent works out your target markets from what you tell it, your locales, currencies and domains. It applies every matching module and states the markets at the top of the report. Markets without a module (for example the US or UK) get the core rules plus a *legal review required* flag.

Want your market covered? See [Contributing](#contributing).

## How it's tested

The repo ships an eval suite ([`plugins/prod-ready/evals/`](plugins/prod-ready/evals/)) built on a small, intentionally vulnerable Express API and Next.js site. It contains SQL injection, an IDOR, a header-based admin check, SSRF, MD5 passwords, leaked keys, analytics without consent and a robots.txt that blocks the whole site.

Graders are deterministic where possible. They check that:
- every item ID appears in the report;
- each planted flaw is marked failed under the right ID;
- unverifiable items are marked *verify manually*;
- the verdict is NO-GO;
- no secret value leaks into the report;
- the report is in the language of the question.

| Run | Score |
|---|---|
| With the plugin (backend TR, frontend TR, frontend EN; 2 runs each) | 6 / 6 runs at 1.0 |
| Same agent without the plugin (v1.0 suite, baseline arm) | 0.33 |

Without the plugin, the agent found most of the obvious code bugs. It never asked about backups, restore tests, CI scanning, admin MFA, audit logging, monitoring or error tracking, and it gave no structured verdict.

Run the suite yourself:

```bash
claude plugin eval plugins/prod-ready --scaffold
```

## Limits

- prod-ready is a checklist and a reviewer, not a scanner. It doesn't replace penetration testing, SAST/DAST tools or dependency scanners. It tells you when to run them and checks whether you do.
- It is not legal advice. Whether your privacy texts are legally adequate is always left to your legal team as a *verify manually* item.
- Code samples show patterns. Check them against the framework versions your project uses.
- Audits read code. Anything that lives only in your cloud console, CI settings or vendor dashboards is reported as a question, not a pass.

## Updating

```bash
claude plugin marketplace update prod-ready-marketplace
claude plugin update prod-ready@prod-ready-marketplace
```

Inside a session you can do the same from the `/plugin` menu. Restart your session to load the new version. Changes are listed in the [CHANGELOG](plugins/prod-ready/CHANGELOG.md).

## Contributing

Issues and pull requests are welcome. The most useful contributions:

- **A privacy module for your market:** for example `privacy-us.md` (CCPA/CPRA) or `privacy-uk.md`. Follow the structure of the existing modules: a frontend section mapped to F17–F21 and a backend section mapped to B39, citing the specific articles.
- **A stack reference:** for example Django, Laravel, Spring, Go, Rails or Nuxt. Code should compile or run against a current version.
- **False positives or misses:** open an issue with the item ID, what the agent reported and what it should have reported.

Before submitting:
1. Keep item IDs stable. New items get new IDs; existing IDs are never renumbered.
2. Run `claude plugin validate plugins/prod-ready --strict`.
3. Run the eval suite and include the scores in the PR.
4. Bump the version in `plugins/prod-ready/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`, and add a CHANGELOG entry.

## License

MIT. See [LICENSE](LICENSE).
