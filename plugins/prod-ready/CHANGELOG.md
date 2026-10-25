# Changelog

## 1.1.0 — 2026-10-25

- Skills and references translated to English. Triggers still include Turkish phrases, and reports are still written in the user's language.
- Privacy items made jurisdiction-aware: a jurisdiction-agnostic core in the checklists, plus market modules `privacy-eu.md` (GDPR, ePrivacy, Consumer Rights Directive, EU representative, European Accessibility Act) and `privacy-tr.md` (KVKK, İYS, distance sales, VERBİS). Audit reports now state the target markets.
- Corrected the Türkiye cross-border transfer rule: since the 2024 amendment, routine transfers need a safeguard such as a standard contract notified to the Board within 5 business days; explicit consent remains only for occasional transfers.
- EU: noted the abolition of the ODR platform and its link obligation (20 July 2025).
- New English eval case (`frontend-audit-en`); report-language graders on all cases.
- Item IDs (B01–B39, F01–F29) and skill names unchanged.

## 1.0.0 — 2026-10-25

- First release: `prod-ready-backend` (B01–B39) and `prod-ready-frontend` (F01–F29).
- Build and Audit modes, GO / NO-GO verdict rule, scoring rules for mixed items.
- Stack references: ASP.NET Core, Node.js, Next.js App Router (including 15/16 differences), React/Vue SPA.
- Eval case built on an intentionally vulnerable sample app.
