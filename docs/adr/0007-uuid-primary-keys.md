# ADR 0007 — UUID Primary Keys on All Domain Tables

**Status:** Accepted
**Date:** 2026-06-03

---

## Context

Rails defaults to `bigint` auto-incrementing primary keys. For most tables this is fine. Ledger-L5 has specific reasons to use UUIDs on domain tables.

---

## Decision

All domain tables (`tenants`, `api_keys`, `usage_events`, `tenant_balances`, `entitlements`, `invoices`) use `uuid` primary keys.

Migration pattern:
```ruby
create_table :tenants, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
  # ...
end
```

PostgreSQL's `gen_random_uuid()` is used (built into Postgres 13+, no extension needed).

---

## Consequences

**Positive:**

1. **No enumeration on API endpoints.** `GET /api/v1/entitlements/1` leaks that exactly 1 tenant exists. `GET /api/v1/entitlements/018e1c2a-7b4f-...` reveals nothing about the total count.

2. **`idempotency_key` is already a UUID.** Upstream callers (EventHorizon, Sentinel) generate a UUID per usage batch. Having a UUID PK on `usage_events` means the idempotency key can optionally serve as the PK directly, avoiding a separate indexed column.

3. **Safe to generate IDs client-side.** If a pipeline service ever needs to pre-generate a `usage_event` ID before insertion (for distributed tracing correlation), UUIDs can be generated anywhere without coordination.

4. **No PK collision risk in multi-source ingestion.** Three different services ingesting events into the same table with `bigint` serial PKs would conflict if we ever considered partitioned inserts. UUID space is collision-resistant.

**Negative / Trade-offs:**

- UUIDs are 16 bytes vs 8 bytes for `bigint`. For the `usage_events` table (potentially millions of rows), this adds storage overhead.
- UUID index pages have lower density than sequential `bigint` — slightly worse B-tree performance for range scans. Mitigated by ensuring `occurred_at` and `tenant_id` are the primary query axes, not PK.
- Rails `find(id)` and URL helpers continue to work — `uuid` is transparently supported by ActiveRecord with PostgreSQL.

**Laravel analogy:**
- `$table->uuid('id')->primary()` in a Laravel migration
- Laravel's `HasUuids` trait generates UUIDs in the model; Rails uses `gen_random_uuid()` at the DB layer (no model-layer generation needed)
