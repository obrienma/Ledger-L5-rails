# ADR 0005 — Entitlement Enforcement: Poll-Based, Fail-Open

**Status:** Accepted
**Date:** 2026-06-03

---

## Context

Ledger-L5 needs to communicate tenant throttle state to upstream pipeline services (EventHorizon, Synapse-L4, Sentinel-L7) so they can gate or allow traffic based on a tenant's billing status.

Three candidate patterns exist:

1. **Shared Redis key** — Ledger-L5 writes `throttled:<tenant_id>` into a shared Redis instance; pipeline services read it directly.
2. **Webhook push** — Ledger-L5 fires a webhook to each pipeline service when entitlement state changes.
3. **Poll endpoint** — Each pipeline service polls `GET /api/v1/entitlements/:tenant_id` on each request (or with a TTL cache) and makes local enforcement decisions.

---

## Decision

Pipeline services **poll `GET /api/v1/entitlements/:tenant_id`** and cache the result with a configurable TTL (default: 30 seconds). Ledger-L5 never initiates outbound calls to pipeline services.

Failure mode is **fail-open**: if Ledger-L5 is unreachable, cached entitlements are served until TTL expiry, and tenants remain unthrottled during any Ledger-L5 outage.

---

## Consequences

**Positive:**
- Coupling is **unidirectional**: EventHorizon/Sentinel/Synapse depend on Ledger-L5, not the reverse. Ledger-L5 can be deployed, restarted, or scaled without coordinating with pipeline services.
- No shared infrastructure: no Redis cluster that both billing and pipeline must connect to.
- Entitlement state is a **single source of truth**: the `entitlements` table. No risk of Redis key diverging from DB state.
- Simple to test: pipeline services mock the endpoint; Ledger-L5 has no callbacks to test.

**Negative / Trade-offs:**
- **Enforcement lag = cache TTL.** A tenant who hits their limit may continue sending events for up to 30 seconds after throttling is set. Acceptable for commercial SaaS billing; not acceptable for hard legal or contractual enforcement windows.
- **Stale cache during Ledger-L5 outage.** This is an explicit product decision: tenants stay unthrottled rather than hard-blocked. Documented here to prevent future engineers from "fixing" the fail-open behavior without understanding the intent.
- Polling adds a small per-request overhead to pipeline services (mitigated by in-process TTL cache).

**Alternatives rejected:**

- **Redis shared key:** Adds a cross-service infrastructure dependency. Both billing and pipeline would need to connect to the same Redis instance. Failure in that Redis cluster takes down entitlement enforcement entirely. Also requires an explicit fail-open/fail-closed policy per consumer.
- **Webhook push:** Creates bidirectional coupling — Ledger-L5 must know about each pipeline service's webhook endpoint, retry on delivery failure, and manage its own retry queue with idempotency. This is the same problem domain we're building in Ledger-L5, applied recursively. It also means Ledger-L5's outbound failures cause pipeline-side inconsistency.

---

## This decision must be re-evaluated if:

- Overage has hard legal or financial consequences (switch to fail-closed)
- Enforcement lag > 30s becomes commercially unacceptable (lower TTL or switch to push)
- The number of polling services grows beyond ~5 (polling fan-out becomes significant DB read load)
