# Ledger-L5

Consumption-based metering and invoicing engine. The commercial layer for the EventHorizon → Synapse-L4 → Sentinel-L7 portfolio. Rails 8, Solid Queue, Stripe Billing Meters, Hotwire.

Pipeline services report usage events; Ledger-L5 aggregates, meters, enforces plan limits, and invoices via Stripe. Operator dashboard streams live usage updates over WebSockets with zero React.

---

## Architecture

```
Pipeline Services (EventHorizon / Synapse-L4 / Sentinel-L7)
        │                               ↑
        │ POST /api/v1/usage            │ GET /api/v1/entitlements/:id
        │ (idempotent, Bearer token)    │ (polled, TTL-cached, fail-open)
        ▼                               │
┌───────────────────────────────────────────────────────────┐
│                     Railway                               │
│                                                           │
│  ┌─────────────────┐     ┌───────────────────────────┐   │
│  │  Web (Puma)     │     │  Worker (jobs:start)       │   │
│  │                 │     │                            │   │
│  │  Operator dash  │     │  AggregateUsageJob         │   │
│  │  API ingestion  │     │  EnforceLimitsJob (nightly)│   │
│  │  Entitlements   │     │  SyncStripeMetersJob       │   │
│  └────────┬────────┘     │  GenerateInvoiceJob        │   │
│           │              └──────────────┬─────────────┘   │
│           └──────────────┬──────────────┘                 │
│                          ▼                                │
│                  ┌───────────────┐                        │
│                  │  PostgreSQL   │                        │
│                  │  Solid Queue  │                        │
│                  │  Solid Cable  │                        │
│                  └───────────────┘                        │
└───────────────────────────────────────────────────────────┘

Browser ←── WebSocket (Solid Cable / Turbo Streams) ──→ Web
```

**Full Mermaid diagrams:** [`docs/architecture.md`](docs/architecture.md)
**Architecture Decision Records:** [`docs/adr/`](docs/adr/)
**Learning Log:** [`LEARNING_LOG.md`](LEARNING_LOG.md)

---

## Stack

| Layer | Technology |
|---|---|
| Framework | Ruby on Rails 8.1 |
| Language | Ruby 3.3.6 |
| Database | PostgreSQL |
| Job Queue | Solid Queue (Postgres-backed, no Redis) |
| WebSockets | Solid Cable (Postgres-backed, no Redis) |
| Real-time UI | Hotwire — Turbo Streams + Turbo Frames |
| CSS | Tailwind CSS v4 |
| Auth (operator) | Devise |
| Billing | Stripe Ruby SDK + Billing Meters API |
| Testing | RSpec + FactoryBot |
| Database host | Neon (serverless Postgres) |
| Deployment | Railway (split web + worker topology) |

---

## Status

- [x] Phase 0 — Ruby 3.3.6 via rbenv, Rails 8.1.3 installed
- [x] Phase 1 — Rails scaffold initialized; renamed to Ledger-L5; gems added (Devise, Stripe, RSpec, FactoryBot)
- [x] Phase 2 — DB created on Neon; 7 migrations run (tenants, api_keys, usage_events, tenant_balances, entitlements, invoices, operators); UUID PKs on all tables; unique index on `usage_events.idempotency_key`; `dotenv-rails` added; all environments (dev/test/prod) use `DATABASE_URL`
- [x] Phase 3 — `Tenant` + `ApiKey` models; `ApiKeyAuthenticatable` concern; bcrypt `{id}.{secret}` token scheme; 15 model specs green
- [x] Phase 4 — `POST /api/v1/usage` ingestion endpoint; `UsageEvent` model; `Api::V1::UsageController` (Bearer auth, idempotent on `idempotency_key`, 202/409/401/422); 8 request specs green
- [x] Phase 5 — `AggregateUsageJob`; `TenantBalance` model; full-recalculation atomic UPDATE via SQL subquery; enqueued by controller on each accepted event; 7 job specs green (31 total)

### What's still ahead
- [ ] Phase 6 — `GET /api/v1/entitlements/:id`
- [ ] Phase 6 — `GET /api/v1/entitlements/:id`
- [ ] Phase 7 — Operator dashboard (Turbo Streams live usage updates)
- [ ] Phase 8 — `EnforceLimitsJob` (nightly), scheduled via Solid Queue recurring
- [ ] Phase 9 — Stripe integration (`SyncStripeMetersJob`, `GenerateInvoiceJob`)
- [ ] Phase 10 — Railway `Procfile` + deployment config

---

## Local Development

```bash
# Prerequisites: Ruby 3.3.6 (rbenv), Neon account
cp .env.example .env        # fill in DATABASE_URL (Neon direct connection string)
bin/rails db:migrate
bin/dev                      # web + worker + Tailwind watcher via Procfile.dev
```

---

## Running Tests

```bash
bundle exec rspec
bundle exec rspec spec/requests/api/v1/usage_spec.rb   # specific file
```

---

## Key Design Decisions

| Decision | Choice | ADR |
|---|---|---|
| Background jobs | Solid Queue (no Redis) | ADR 0002 |
| WebSockets | Solid Cable (no Redis) | ADR 0002 |
| Real-time UI | Hotwire/Turbo (no React) | ADR 0003 |
| Entitlement enforcement | Poll-based, fail-open | ADR 0005 |
| Operator auth | Devise | ADR 0006 |
| Primary keys | UUID (`gen_random_uuid()`) | ADR 0007 |
| Test framework | RSpec + FactoryBot | ADR 0008 |

---

## Deployment (Railway)

Split-service topology: **web** process (Puma) + **worker** process (`bundle exec jobs:start`) share one PostgreSQL instance.

Required environment variables:
- `DATABASE_URL` — auto-provided by Railway Postgres plugin
- `RAILS_MASTER_KEY` — copy from `config/master.key`
- `STRIPE_SECRET_KEY` — from Stripe dashboard
- `SOLID_QUEUE_IN_PUMA=false` — worker process owns jobs, not Puma
