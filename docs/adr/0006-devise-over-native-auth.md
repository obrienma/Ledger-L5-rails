# ADR 0006 — Devise Over Native Rails Authentication Generator

**Status:** Accepted
**Date:** 2026-06-03

---

## Context

Ledger-L5 needs authentication for the **operator dashboard** — the internal UI used by billing team members to manage tenants, review invoices, suspend accounts, and configure plans.

Rails 8 ships a native authentication generator (`bin/rails generate authentication`) that creates a minimal `User` + `Session` model, a sessions controller, and a basic password reset flow. No gem required.

Devise is the longstanding Rails authentication gem, providing a full suite of authentication features via a modular concern system.

---

## Decision

Use **Devise** for operator authentication.

Configured modules for the `Operator` model:
- `database_authenticatable` — password storage and validation
- `registerable` — operator account creation
- `recoverable` — password reset via email
- `rememberable` — "remember me" cookie
- `validatable` — email/password format validation
- `lockable` — account lockout after N failed attempts (important for an admin interface)
- `trackable` — last sign-in IP and timestamp (audit trail for operator actions)

---

## Consequences

**Positive:**
- **Account lockout** (`lockable`) is not provided by the native generator. An operator dashboard without lockout is a brute-force risk.
- **Remember me** (`rememberable`) is a standard operator UX expectation — not provided natively.
- **Trackable** gives a built-in audit trail: last sign-in at/IP per operator. Useful for compliance questions about "who changed a tenant's plan?"
- Devise's password reset flow is battle-tested and handles edge cases (token expiry, race conditions) that a custom implementation would need to re-solve.

**Negative / Trade-offs:**
- Devise is a heavy gem with a lot of magic (callbacks, warden integration, engine-mounted routes). It can be opaque when debugging.
- Devise's views are dated and need customization for Tailwind. We'll run `bin/rails generate devise:views` and restyle.
- Native generator + Devise cannot coexist easily — we don't mix them. Devise owns all operator auth.

**Note:** The external API uses a separate authentication mechanism — `ApiKey` digest lookup, not Devise. Devise is strictly for operator session management, not for authenticating pipeline services hitting `POST /api/v1/usage`.

**Laravel analogy:**
- Devise ↔ Laravel Breeze/Jetstream with the full feature set enabled (lockout, 2FA available, etc.)
- The native Rails generator ↔ Laravel Breeze with only the bare minimum scaffolded
