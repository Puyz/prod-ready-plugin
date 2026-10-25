# EU / EEA — GDPR, ePrivacy and consumer rules

This file lists what the launch checklist must verify. It is not legal advice: legal adequacy of texts is always ❓ and goes to legal review.

**Applies when** you offer goods or services to people in the EU/EEA or monitor their behavior there, regardless of where the company is established (GDPR Art. 3(2)).

## Frontend (F17–F21, F25)

### F17 — Cookies and trackers (ePrivacy Art. 5(3) + GDPR consent standard)
- Storing or reading non-essential cookies, local storage, pixels or fingerprinting requires **prior consent**. Strictly necessary items (session, load balancing, the consent cookie itself, cart) do not.
- Consent must be freely given, specific, informed and unambiguous (GDPR Art. 4(11), Art. 7). Pre-ticked boxes are invalid (CJEU C-673/17 *Planet49*).
- Rejecting must be as easy as accepting: a "Reject all" option on the first layer, with the same prominence as "Accept all".
- Withdrawing consent must be as easy as giving it (Art. 7(3)): a persistent "Cookie settings" link.
- "Cookie walls" that block the site unless the user accepts are generally not valid consent.
- You must be able to demonstrate consent (Art. 7(1)): store the choice, the timestamp and the banner/policy version.

### F18 — Privacy notice content (GDPR Art. 13)
The notice shown where data is collected must include:
- Identity and contact details of the controller, and the DPO's contact if one is appointed.
- Each purpose of processing **with its legal basis** (Art. 6); the legitimate interest pursued if that basis is used.
- Recipients or categories of recipients.
- Transfers outside the EEA and the safeguard used (adequacy decision, SCCs, etc.).
- Retention period, or the criteria used to set it.
- The rights of access, rectification, erasure, restriction, portability and objection, and the right to withdraw consent.
- The right to lodge a complaint with a supervisory authority.
- Whether providing the data is required, and the consequences of not providing it.
- Any automated decision-making or profiling with legal or similarly significant effects.

Marketing email/SMS needs its own separate opt-in (ePrivacy Art. 13; national rules vary for existing customers).

### F19 — Consumer contract information (e-commerce)
- Consumer Rights Directive 2011/83/EU: pre-contract information (trader identity, total price incl. taxes, delivery, payment), a **14-day right of withdrawal** with the model withdrawal form, and an order button labeled to make the payment obligation clear (e.g. "Order with obligation to pay", Art. 8(2)).
- The EU Online Dispute Resolution (ODR) platform was abolished by Regulation (EU) 2024/3228 with effect from 20 July 2025, and with it the obligation to link to it. Remove stale ODR links (they can now mislead consumers) and confirm national ADR information duties with legal.

### F20 — Trader and controller identity
- E-Commerce Directive Art. 5: name, geographic address, email, trade register number and VAT number, if applicable. Some member states require a dedicated legal notice page (e.g. the German *Impressum*).
- **EU representative (GDPR Art. 27):** a controller without an EU establishment must appoint one, unless processing is occasional and low-risk. Name them in the privacy notice.

### F21 — Analytics
- Analytics cookies are non-essential and need consent. Cookieless or "consent-exempt" analytics setups vary by country; treat any exemption claim as ❓ for legal review.

### F25 — Accessibility (European Accessibility Act)
- Since 28 June 2025, e-commerce services offered to EU consumers must meet the EAA accessibility requirements (in practice WCAG 2.1 AA via EN 301 549); microenterprises providing services are exempt. For a covered business, F25 failures become a legal issue as well as a UX one.

## Backend (B39)
- **Principles (Art. 5):** data minimization, purpose limitation, storage limitation. Each data category has a defined retention period, enforced by automatic deletion.
- **Data subject rights (Art. 15–22):** access, erasure and portability (structured, machine-readable export) can be fulfilled. Answer within one month (Art. 12(3)). Deletion also covers processors and is consistent with backup retention.
- **Records and contracts:** a record of processing activities (Art. 30) and a data processing agreement with every processor (Art. 28): hosting, email, analytics, payment, AI APIs.
- **Transfers (Chapter V):** adequacy decision (e.g. US companies certified under the EU–US Data Privacy Framework), or Standard Contractual Clauses with a transfer impact assessment.
- **Breaches (Art. 33–34):** notify the supervisory authority within 72 hours of becoming aware. Logging and alerting (B31, B38) must make detection possible.
- **Security (Art. 32):** appropriate technical measures; the backend checklist items are the evidence.
- **DPIA (Art. 35):** required for high-risk processing (large-scale special categories, systematic monitoring). Ask ❓ if such processing exists.
