# ADR 0004 — Railway Split-Service Topology (Web + Worker)

**Status:** Accepted
**Date:** 2026-06-03

---

## Context

Ledger-L5 requires two concurrent runtime processes:

1. **Web process** — Puma HTTP server serving the dashboard and API ingestion endpoint
2. **Worker process** — Solid Queue job runner (`bundle exec jobs:start`) processing `ProcessLogEntryJob` asynchronously

Railway supports two deployment models:
- **Single service with `Procfile.dev`** — suitable for local development only
- **Split services** — separate Railway service definitions, each running one process, both pointing at the same Postgres database

---

## Decision

Deploy as **two Railway services** sharing one PostgreSQL database add-on:

| Service | Start command | Role |
|---|---|---|
| `wire-trace-web` | `bundle exec puma -C config/puma.rb` | HTTP + WebSocket |
| `wire-trace-worker` | `bundle exec jobs:start` | Background jobs |

Both services are configured with the same `DATABASE_URL` (Railway Postgres add-on) and `RAILS_MASTER_KEY`.

A `Procfile` at the repo root defines both process types for Railway:
```
web: bundle exec puma -C config/puma.rb
worker: bundle exec jobs:start
```

`SOLID_QUEUE_IN_PUMA=false` is set on the web service to prevent Puma from also trying to run jobs inline (default in development).

---

## Consequences

**Positive:**
- Web and worker scale independently — if job throughput increases, scale the worker without touching web
- Worker crash does not take down the HTTP layer (jobs accumulate in the queue, no data loss)
- Clean separation of concerns maps directly to the Procfile `web`/`worker` convention
- No extra infrastructure: no Heroku-style dynos complexity, no Kubernetes, no Docker Compose in production

**Negative / Trade-offs:**
- Two Railway services = two billed instances (though Railway's free tier covers both for a portfolio project)
- Deployment must update both services; Railway's GitHub integration handles this automatically from a single repo

**To be updated:** Final env var configuration added after Railway deploy in Phase 8.

**Laravel analogy:**
- `bundle exec jobs:start` ↔ `php artisan queue:work`
- Railway worker service ↔ a Render/Fly.io worker dyno running `queue:work`
