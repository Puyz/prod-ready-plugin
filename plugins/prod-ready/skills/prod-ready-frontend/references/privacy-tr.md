# Türkiye — KVKK, commercial messaging and e-commerce rules

This file lists what the launch checklist must verify. It is not legal advice: legal adequacy of texts is always ❓ and goes to legal review. Turkish terms are kept in parentheses because Turkish legal teams and documents use them.

**Applies when** personal data of people in Türkiye is processed (Law No. 6698 on the Protection of Personal Data, "KVKK"), and to commercial messages and e-commerce aimed at Turkish consumers.

## Frontend (F17–F21)

### F17 — Cookies (KVKK Board Cookie Guide, 2022)
- Non-essential cookies (analytics, marketing, personalization) require **explicit consent** (açık rıza) before they are set. Strictly necessary cookies do not.
- Pre-ticked boxes and "by continuing you accept" are not valid consent. Accept and reject options must be equally prominent.
- The choice can be changed later.

### F18 — Information notice and consent texts
- **Information notice (aydınlatma metni, KVKK Art. 10 and the Communiqué on the Obligation to Inform):** controller identity, purposes, to whom and why data is transferred, the method and legal basis of collection, and the Art. 11 rights. Shown at the point of collection.
- **Explicit consent (açık rıza)** is used only where no other legal basis (Art. 5–6) applies. It must be specific, informed and freely given; it must not be a condition of the service; it is a **separate, optional** checkbox.
- The information notice and the explicit consent text must be **separate documents**; never merge them into one checkbox or one text.
- **Commercial electronic messages (Law No. 6563 and its Regulation):** marketing email/SMS/calls need prior opt-in consent, and senders must register consents in the Message Management System (İleti Yönetim Sistemi, **İYS**). Every message must include an easy opt-out.

### F19 — E-commerce consumer documents (Law No. 6502, Distance Contracts Regulation)
- **Pre-information form** (ön bilgilendirme formu) and **distance sales contract** (mesafeli satış sözleşmesi) shown before the order, with the consumer confirming they have read the pre-information.
- **14-day right of withdrawal** (cayma hakkı) and its exceptions explained; return and cancellation terms reachable from the footer and checkout.

### F20 — Service provider identity (Law No. 6563 Art. 3)
- Legal name (unvan), MERSİS number, address, email and phone, trade registry details and, if applicable, professional chamber. Also the KVKK application channel for data subject requests.

### F21 — Analytics
- Analytics cookies need explicit consent. Analytics providers abroad (e.g. Google) mean a cross-border transfer; see "Transfers" below.

## Backend (B39)
- **Cross-border transfers (KVKK Art. 9, as amended by Law No. 7499, in force since 1 June 2024):**
  - Allowed with an adequacy decision, or with appropriate safeguards: **standard contracts** (standart sözleşme) published by the Board, binding corporate rules, or undertakings.
  - A signed standard contract must be **notified to the Board within 5 business days**.
  - Explicit consent is no longer the main route; it remains only for **occasional (arızi)** transfers. Routine transfers to cloud, analytics, payment or AI providers need a safeguard.
- **Data subject requests (Art. 11, 13):** access, correction, erasure and objection requests are answered within **30 days**.
- **Erasure (Regulation on Erasure, Destruction or Anonymization):** data whose purpose has ended is erased, destroyed or anonymized; periodic destruction runs at intervals of at most **6 months**. Controllers required to register with VERBİS must also have a personal data retention and destruction policy.
- **VERBİS (Data Controllers' Registry):** registration is required above the employee/balance-sheet thresholds or when the main activity involves special category data. Thresholds change; ask ❓ whether registration has been assessed.
- **Breaches (Art. 12):** notify the Board within **72 hours** and inform affected people. Logging and alerting (B31, B38) must make detection possible.
- **Processors:** a written data processing agreement with every processor; joint liability for security under Art. 12.
- **Special category data (Art. 6):** health, biometric and similar data need additional measures (the Board's decision on adequate measures). Ask ❓ if such data is processed.
