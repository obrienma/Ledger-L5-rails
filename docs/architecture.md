# Ledger-L5 — Architecture

## System Overview

Ledger-L5 is the commercial layer of the EventHorizon → Synapse-L4 → Sentinel-L7 portfolio. Pipeline services report usage events to Ledger-L5; Ledger-L5 aggregates, meters, and bills. Entitlement state flows back to pipeline services via a poll endpoint (unidirectional coupling — see ADR 0005).

```mermaid
graph TD
    subgraph Pipeline Services
        EH[EventHorizon]
        SY[Synapse-L4]
        SL[Sentinel-L7]
    end

    subgraph Ledger-L5 - Web Process
        API_USAGE[POST /api/v1/usage]
        API_ENT[GET /api/v1/entitlements/:id]
        DASH[Operator Dashboard\nHotwire + Turbo Streams]
    end

    subgraph Ledger-L5 - Worker Process
        AGG[AggregateUsageJob]
        ENFORCE[EnforceLimitsJob\nnightly]
        STRIPE_SYNC[SyncStripeMetersJob\nnightly]
        INV[GenerateInvoiceJob\nmonthly]
    end

    subgraph PostgreSQL
        DB[(ledger_l5 DB\napp tables\nSolid Queue\nSolid Cable)]
    end

    subgraph Stripe
        METERS[Billing Meters API]
        INVOICES_STRIPE[Invoice API]
    end

    EH -->|POST usage + idempotency_key| API_USAGE
    SY -->|POST usage + idempotency_key| API_USAGE
    SL -->|POST usage + idempotency_key| API_USAGE

    EH -->|GET entitlements cached TTL=30s| API_ENT
    SY -->|GET entitlements cached TTL=30s| API_ENT
    SL -->|GET entitlements cached TTL=30s| API_ENT

    API_USAGE -->|enqueue job| DB
    DB -->|poll| AGG
    AGG -->|UPDATE tenant_balances| DB
    AGG -->|broadcast Turbo Stream| DB

    ENFORCE -->|nightly| DB
    STRIPE_SYNC -->|push daily delta| METERS
    INV -->|finalize| INVOICES_STRIPE

    DASH <-->|WebSocket Solid Cable| DB
```

---

## Usage Ingestion — Request Lifecycle

```mermaid
sequenceDiagram
    participant C as Pipeline Service
    participant W as Ledger-L5 Web (Puma)
    participant DB as PostgreSQL
    participant J as Worker Process
    participant O as Operator Browser

    C->>W: POST /api/v1/usage<br/>Authorization: Bearer api_key<br/>{ tenant_id, idempotency_key, event_type, quantity, occurred_at }

    W->>W: ApiKeyAuthenticatable<br/>digest match on api_keys.token_digest

    alt idempotency_key already exists
        W->>DB: SELECT usage_events WHERE idempotency_key = ?
        DB-->>W: existing row
        W-->>C: 200 OK idempotent success no re-enqueue
    else new event
        W->>DB: INSERT usage_events raises RecordNotUnique on race
        W->>DB: enqueue AggregateUsageJob
        W-->>C: 202 Accepted
    end

    DB-->>J: job available Solid Queue poll
    J->>DB: UPDATE tenant_balances SET current_usage = (SELECT SUM(quantity) FROM usage_events WHERE tenant_id = ? AND occurred_at BETWEEN period_start AND period_end)<br/>atomic full-period recalculation, not an increment
    J->>DB: reload Tenant WITH tenant_balance, entitlement<br/>avoids broadcasting a stale pre-update object
    J->>O: broadcast_replace_to "dashboard"<br/>target=tenant_id via Turbo::StreamsChannel (Solid Cable pubsub)
```

---

## Entitlement Read Path

```mermaid
sequenceDiagram
    participant P as Pipeline Service
    participant Cache as In-Process TTL Cache
    participant W as Ledger-L5 Web
    participant DB as PostgreSQL

    P->>Cache: check entitlements[tenant_id]
    alt cache hit TTL not expired
        Cache-->>P: throttled false plan pro current_usage 420.5
    else cache miss or expired
        P->>W: GET /api/v1/entitlements/:id<br/>Authorization: Bearer api_key
        W->>DB: SELECT entitlement, tenant_balance scoped to current_tenant
        DB-->>W: entitlement + balance rows
        W-->>P: id throttled throttled_at plan current_usage
        P->>Cache: store with TTL=30s
    end
    P->>P: enforce locally allow or gate
```

**Fail-open:** if Ledger-L5 is unreachable, pipeline uses stale cached value until TTL expires, then fails open (allows traffic). Documented in ADR 0005.

---

## Domain Model

```mermaid
erDiagram
    OPERATOR {
        uuid id PK
        string email
        string encrypted_password
        datetime remember_created_at
        string reset_password_token
        datetime reset_password_sent_at
    }

    TENANT {
        uuid id PK
        string name
        string plan
        string status
        string stripe_customer_id
    }

    API_KEY {
        uuid id PK
        uuid tenant_id FK
        string name
        string token_digest
        boolean active
    }

    USAGE_EVENT {
        uuid id PK
        uuid tenant_id FK
        string idempotency_key
        string event_type
        decimal quantity
        datetime occurred_at
        jsonb metadata
    }

    TENANT_BALANCE {
        uuid id PK
        uuid tenant_id FK
        decimal current_usage
        date period_start
        date period_end
    }

    ENTITLEMENT {
        uuid id PK
        uuid tenant_id FK
        boolean throttled
        datetime throttled_at
    }

    INVOICE {
        uuid id PK
        uuid tenant_id FK
        string stripe_invoice_id
        date period_start
        date period_end
        integer amount_cents
        string status
        datetime paid_at
    }

    TENANT ||--o{ API_KEY : "has many"
    TENANT ||--o{ USAGE_EVENT : "has many"
    TENANT ||--|| TENANT_BALANCE : "has one"
    TENANT ||--|| ENTITLEMENT : "has one"
    TENANT ||--o{ INVOICE : "has many"
```

---

## Railway Deployment Topology

```mermaid
graph LR
    subgraph Railway Project
        WEB[Web Service\nbundle exec puma]
        WORKER[Worker Service\nbundle exec jobs:start]
        PG[(PostgreSQL\nAdd-on)]
    end

    WEB -->|DATABASE_URL| PG
    WORKER -->|DATABASE_URL| PG
    PG -.->|Solid Queue tables| WORKER
    PG -.->|Solid Cable tables| WEB
```

Both worker and web share one `DATABASE_URL`. No Redis. No Sidekiq. No Pusher.
