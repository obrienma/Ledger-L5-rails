# ADR 0002 — No Redis: Solid Queue + Solid Cable over PostgreSQL

**Status:** Accepted
**Date:** 2026-06-03

---

## Context

Real-time Rails applications traditionally require Redis for two distinct roles:

1. **Job queue backend** — Sidekiq reads from Redis sorted sets to schedule and execute background jobs
2. **WebSocket pub/sub** — Action Cable's default adapter uses Redis pub/sub to fan out broadcasts to all connected Puma threads/processes

This creates a hard operational dependency: any downtime or misconfiguration of Redis causes both the job pipeline and real-time updates to fail simultaneously.

For a Railway-hosted project, Redis is a separate paid add-on with its own connection limits, memory tier, and failure surface.

---

## Decision

Use **Solid Queue** (job queue) and **Solid Cable** (WebSocket adapter), both of which use PostgreSQL as their backing store.

- `solid_queue` — ships with Rails 8 default; configured in `config/queue.yml`
- `solid_cable` — ships with Rails 8 default; configured in `config/cable.yml`

Both were auto-installed by `rails new` and are already configured in this app.

---

## Consequences

**Positive:**
- Single data store (PostgreSQL) for application data, job queue, WebSocket pub/sub, and cache
- Railway provisioning is simpler: one Postgres add-on, one `DATABASE_URL`, done
- No Redis connection pool to tune; no Redis OOM (Out of Memory) incidents
- Solid Queue's Postgres tables are inspectable with standard SQL — easier debugging than Redis `MONITOR`
- Lower cost: no separate Redis instance billing

**Negative / Trade-offs:**
- **Throughput ceiling:** Solid Queue processes ~hundreds to low-thousands of jobs/sec vs Sidekiq's tens-of-thousands. Acceptable for telemetry ingestion at portfolio scale.
- **Pub/sub latency:** Solid Cable polls Postgres for new messages rather than using Redis SUBSCRIBE. Latency is ~50–200ms vs ~1–5ms for Redis. Imperceptible on a log dashboard.
- **Lock contention:** At very high concurrency, Solid Queue's Postgres-based locking can become a bottleneck. Not relevant here.

**Laravel analogy:**
- Solid Queue + Postgres ↔ Laravel queue driver set to `database` (vs `redis`)
- Solid Cable ↔ Laravel Broadcasting with the `database` driver instead of Pusher/Soketi
