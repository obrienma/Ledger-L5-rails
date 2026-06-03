# ADR 0001 — Choose Ruby on Rails 8 with the Solid Stack

**Status:** Accepted
**Date:** 2026-06-03

---

## Context

We need a backend framework to build a real-time telemetry and log monitoring dashboard. Requirements:

- High-throughput API ingestion endpoint (POST JSON payloads)
- Asynchronous background processing (pattern matching, record creation)
- Real-time dashboard updates pushed to connected browsers without polling
- Postgres as the sole data store (no operational complexity of Redis)
- Single-engineer project — minimize the number of moving parts

The developer is coming from a Laravel background and wants to gain Rails experience.

---

## Decision

Use **Ruby on Rails 8** with the **Solid Stack**:

- **Solid Queue** — Postgres-backed ActiveJob backend (replaces Sidekiq/Redis for job queues)
- **Solid Cable** — Postgres-backed Action Cable adapter (replaces Redis pub/sub for WebSockets)
- **Solid Cache** — Postgres-backed cache store (available if needed; not primary motivation here)

Rails 8 ships all three in the default `Gemfile`, configured out of the box.

---

## Consequences

**Positive:**
- Zero Redis dependency — one fewer service to provision, monitor, and pay for
- Postgres already required for ActiveRecord; Solid Stack piggybacks on the same connection
- Rails 8 "One-Person Framework" philosophy aligns with single-engineer scope
- Hotwire (Turbo + Stimulus) is the Rails-native answer to React for real-time UI — ships default
- Native authentication generator (`bin/rails generate authentication`) eliminates auth gems

**Negative / Trade-offs:**
- Solid Queue has lower throughput ceiling than Sidekiq + Redis at extreme scale (millions of jobs/sec) — acceptable for a portfolio/learning project
- Solid Cable's Postgres pub/sub adds some latency vs Redis pub/sub (~5–20ms vs ~1ms) — imperceptible at dashboard scale
- Smaller community around Solid Stack than Sidekiq; fewer Stack Overflow answers

**Laravel analogy:**
- Solid Queue ↔ Laravel Horizon (Redis) or database queue driver
- Solid Cable ↔ Laravel Echo + Pusher/Soketi
- Hotwire/Turbo ↔ Livewire (server-driven reactivity without writing a SPA)
