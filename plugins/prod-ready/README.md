# prod-ready

Production readiness checklists for backends and web frontends, for Claude Code. The skills apply the rules while you write code, and on request audit a project and produce an evidence-based **GO / NO-GO** report.

## What's inside

| Skill | Scope |
|---|---|
| `prod-ready-backend` | 39 items in 12 areas: authentication, authorization/IDOR, injection and SSRF, CSRF/CORS/HTTPS/headers, rate limiting, file upload, secret management, errors and audit logging, database/BaaS, backups, supply chain/CI, operations and privacy. Stack notes: ASP.NET Core (a reference `Program.cs` that compiles on .NET 8 and 10) and Node.js (Express/NestJS/Next route handlers). |
| `prod-ready-frontend` | 29 items: security (bundle secrets, XSS, CSP), SEO (meta, robots, sitemap, OG), 404/500 and loading/form error states, privacy law (consent, notices, consumer contract info), analytics, mobile, images, Core Web Vitals, accessibility, dependency CVEs. Stack notes: Next.js App Router, React/Vue SPA. Privacy modules: EU/EEA (GDPR, ePrivacy, consumer rules, EAA) and Türkiye (KVKK, İYS, distance sales). |

Every item has an ID (B01–B39, F01–F29) and a severity (BLOCKER / HIGH / MEDIUM).

## Usage

The skills trigger automatically; you can also invoke them by name.

- **Build mode:** when you write auth, endpoints, forms, uploads or pages, the relevant items become the default behavior.
  > "Write a login endpoint for Express"
- **Audit mode:** every item is scored ✅ / ❌ / ⚠️ / ➖ / ❓ with `file:line` evidence. Items that cannot be verified from code (backup restore tests, infrastructure MFA, DB network access, Lighthouse) are listed as "verify manually" questions. Any open BLOCKER means NO-GO.
  > "Is this project production ready?" · "Audit the frontend before launch"

Reports are written in the language you write in. Privacy items are checked against the rules of your target markets; markets without a module get the core rules plus a "legal review required" flag.

## Installation

```bash
claude plugin marketplace add Puyz/prod-ready-plugin
claude plugin install prod-ready@prod-ready-marketplace
```

Start a new session after installing. If you previously copied the same skills into `~/.claude/skills/`, remove those copies so they don't appear twice.

## Limits

- This is a checklist. It does not replace a penetration test, SAST/DAST tooling or legal advice.
- The legal adequacy of privacy texts is always left to your legal team as a "verify manually" item.
- Code samples show patterns; verify them against the versions your project uses.

## Development

The cases under `evals/` run audit mode against an intentionally vulnerable sample app, in English and Turkish:

```bash
claude plugin eval plugins/prod-ready --scaffold
```

See [CHANGELOG.md](CHANGELOG.md) for changes.

---

## Türkçe

Backend ve web frontend için production'a çıkış kontrol listeleri. Kod yazarken kuralları uygular; istendiğinde projeyi denetleyip kanıta dayalı bir **GO / NO-GO** raporu üretir. Skill'ler Türkçe sorulara da tetiklenir ve rapor Türkçe yazılır. Gizlilik maddeleri hedef pazara göre kontrol edilir; Türkiye için KVKK, İYS ve mesafeli satış kuralları ayrı bir modülde yer alır. Kurulum için yukarıdaki iki komutu kullan.
