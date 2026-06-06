# Ledger-L5 Learning Log

A running record of patterns learned, anti-patterns avoided, challenges encountered, and design decisions made while building Ledger-L5 with Ruby on Rails 8.

---

## Phase 0 — Environment Setup (Ruby + Rails Installation)

**Date:** 2026-06-03
**Scope:** Install Ruby 3.3.6 via rbenv on WSL2 Ubuntu; install Rails 8.1.3

---

### Patterns

**Pattern: rbenv for Ruby version management**

> Q: Why use rbenv instead of installing Ruby system-wide via `apt`?
> A: `apt`'s Ruby package lags behind current releases (often Ruby 3.1 on Ubuntu 22.04 when 3.3 is current). rbenv installs per-user into `~/.rbenv/` — no `sudo` needed for gem installs, no system Ruby pollution, and version switching (`rbenv local 3.x.x`) is per-directory. This mirrors how NVM manages Node in this environment.

**Pattern: rbenv-installer script**

> Q: What does the rbenv-installer script actually set up?
> A: It installs both `rbenv` itself (the shim layer) AND `ruby-build` (the compilation plugin). Without `ruby-build`, `rbenv install <version>` doesn't exist. The installer writes rbenv init to `~/.zprofile` (for zsh login shells) so shims load on every new terminal.

**Pattern: `rbenv global` vs `rbenv local`**

> Q: When do you use `rbenv global` vs `rbenv local`?
> A: `rbenv global` sets the fallback Ruby for the entire user account (writes to `~/.rbenv/version`). `rbenv local` writes a `.ruby-version` file in the current directory — this overrides global for that project. Convention: set global to your primary version; use local for projects that pin a different version. Ledger-L5 will get a `.ruby-version` file when the Rails app is initialized.

---

### Anti-Patterns

**Anti-Pattern: `sudo gem install rails`**

> Q: Why is `sudo gem install rails` wrong?
> A: It installs into the system Ruby (managed by apt), not rbenv's Ruby. Every subsequent `gem install` also needs sudo. Breaks when you switch Ruby versions. With rbenv, gems install to `~/.rbenv/versions/<version>/lib/ruby/gems/` — fully user-owned, no sudo ever needed.

---

### Challenges

**Challenge: `sudo` unavailable in non-interactive shell**

The rbenv installer and `gem install` ran fine without sudo, but the initial `apt-get` for build dependencies (libssl-dev, libreadline-dev, etc.) required an interactive terminal for the sudo password. The tool shell is non-interactive, so `sudo` blocked. Workaround: user ran that one command manually via `! sudo apt-get install ...` in the Claude Code terminal, then handed back control.

This is a recurring WSL2 constraint: anything needing sudo must be run by the user directly.

---

### Decisions

**Decision: Ruby 3.3.6 (not 3.4.x)**

> Q: Why 3.3.6 and not the latest 3.4.x?
> A: Rails 8.1.3 is tested against and recommends Ruby 3.2+. Ruby 3.3.x is the current stable series with the widest ecosystem support. Ruby 3.4 is newer and some gems haven't caught up yet. 3.3.6 is the latest patch of the stable series — best balance of currency and compatibility.

**Decision: rbenv over rvm**

> Q: Why rbenv over rvm?
> A: rvm is heavier — it monkey-patches `cd`, uses shell functions, and can conflict with other tools. rbenv is a thin shim layer that intercepts Ruby commands via `PATH` ordering. The WSL2 environment already uses NVM for Node (same shim philosophy), making rbenv the consistent choice. Laravel background context: this mirrors Composer's per-project isolation without needing a system-level package manager.

---

## Phase 1 — Rails App Initialization (`rails new`)

**Date:** 2026-06-03
**Scope:** `rails new . --css=tailwind --database=postgresql` in the Ledger-L5 directory

---

### Patterns

**Pattern: `rails new .` (dot) initializes into the current directory**

> Q: What's the difference between `rails new ledger_l5` and `rails new .`?
> A: `rails new ledger_l5` creates a new subdirectory named `ledger_l5/`. `rails new .` scaffolds into the current directory — useful when the directory already exists (e.g., already created on GitHub and cloned). Rails derives the app name from the directory name. In this case the directory is `Ledger-L5`, so the app module is named `Ledger-L5`.

**Pattern: `--css=tailwind` wires up Tailwind via the standalone CSS binary**

> Q: What does `--css=tailwind` actually install and configure?
> A: It adds the `tailwindcss-rails` gem, which wraps the standalone Tailwind CLI binary (no Node.js required). It creates `app/assets/tailwind/application.css` as the input file and adds a `tailwindcss:build` rake task. The `Procfile.dev` includes `css: bin/rails tailwindcss:watch` so Tailwind rebuilds on file changes during development. Rails 8 uses Tailwind v4 (the new CSS-first config, no `tailwind.config.js`).

**Pattern: Rails 8 installs the Solid Stack automatically**

> Q: Do you have to manually add Solid Queue/Cable/Cache?
> A: No. `rails new` runs `rails solid_cache:install solid_queue:install solid_cable:install` as part of the generator. This creates `config/queue.yml`, `config/cache.yml`, `config/cable.yml`, and corresponding schema files (`db/queue_schema.rb`, `db/cache_schema.rb`, `db/cable_schema.rb`). These are separate schema files — not part of `db/schema.rb` — because Solid Stack tables live in the same DB but are managed independently.

**Pattern: `Procfile.dev` vs `Procfile`**

> Q: What's the difference between `Procfile.dev` and `Procfile`?
> A: `Procfile.dev` is for local development only — run by Foreman via `bin/dev`, starts web + worker + Tailwind watcher concurrently. `Procfile` (created in Phase 8) is for production/Railway: defines `web` and `worker` process types that Railway reads to spin up separate service instances. Never use `Procfile.dev` in production.

---

### Anti-Patterns

**Anti-Pattern: `rails new --api` when the app has a browser dashboard**

> Q: Should you use `--api` because Ledger-L5 has an API endpoint?
> A: No. `--api` strips the middleware and view layer needed for Hotwire (sessions, cookies, flash, ERB rendering). Ledger-L5 is hybrid: an API ingestion endpoint AND a browser dashboard. `--api` is only for pure JSON backends consumed by a separate frontend.

---

### Challenges

**Challenge: Kamal installed by default — irrelevant to Railway**

Rails 8 includes Kamal (Docker-based VPS deployment tool) in the default `Gemfile` and runs `bundle exec kamal init` during `rails new`. This created `config/deploy.yml` and `.kamal/secrets` — configuration for a workflow we're not using (Railway uses Buildpacks, not Docker + Kamal). Files are harmless but are deployment-tool noise. Left in place; revisit if they cause confusion.

---

### Decisions

**Decision: `--database=postgresql` from day one**

> Q: Rails defaults to SQLite — why override immediately?
> A: Railway provisions PostgreSQL, not SQLite. Switching adapters mid-project risks data-type incompatibilities (SQLite lacks native UUID, enum, and JSON column types). The Solid Stack schemas are also written assuming Postgres-compatible SQL. Postgres from the start avoids a forced context switch.

**Decision: No `--skip-bundle`**

> Q: Is `--skip-bundle` worth using to review the Gemfile first?
> A: Only if you need to swap gems before the first install. We didn't need to, so it was dropped. `rails new` runs `bundle install` automatically at the end — it's the same result with one fewer manual step.

---

## Phase 2 — Project Pivot: Ledger-L5 → Ledger-L5

**Date:** 2026-06-03
**Scope:** Rename app from Ledger-L5 (telemetry) to Ledger-L5 (metering & invoicing). Add Devise, Stripe, RSpec, FactoryBot.

---

### Patterns

**Pattern: Reusing a Rails scaffold on a pivot — what actually needs changing**

> Q: When you rename a Rails app, what has the old name baked in?
> A: Five things: (1) `config/application.rb` — the `module AppName` declaration, (2) `config/database.yml` — all database names use `app_name_development/test/production`, (3) `config/deploy.yml` — Kamal service and image names, (4) `app/views/pwa/manifest.json.erb` — PWA display name, (5) the directory itself. Nothing in `app/`, `config/routes.rb`, or the Solid Stack config references the app name — those are clean. A Rails scaffold at Phase 1 (no domain logic yet) takes under 5 minutes to rename.

**Pattern: Devise install sequence**

> Q: What's the correct order for installing Devise?
> A: (1) Add `gem "devise"` to Gemfile, (2) `bundle install`, (3) `bin/rails generate devise:install` — this creates `config/initializers/devise.rb` and `config/locales/devise.en.yml` and prints required manual steps, (4) follow the printed instructions (set `default_url_options` in development.rb, add flash messages to layout), (5) `bin/rails generate devise Operator` — generates the model, migration, and routes. Don't skip step 3 before step 5; the initializer must exist before the model generator runs.

**Pattern: RSpec generator overwrites minitest defaults**

> Q: After installing `rspec-rails`, do Rails generators still produce minitest files?
> A: By default yes — some generators still emit `_test.rb` stubs. Fix: add `config.generators.test_framework :rspec` to `config/application.rb`. Then `bin/rails generate model Tenant ...` produces `spec/models/tenant_spec.rb` instead of `test/models/tenant_test.rb`.

---

### Anti-Patterns

**Anti-Pattern: Keeping `test/` alongside `spec/`**

> Q: Is it OK to have both `test/` and `spec/` in the project?
> A: No — it's confusing and CI will try to run both unless explicitly configured to skip one. If you choose RSpec, delete `test/` immediately. Mixed test directories cause "why isn't this test running?" confusion months later.

---

### Challenges

**Challenge: `--skip-action-mailer` in the original plan was a non-issue**

The original build plan mentioned `--skip-action-mailer` as part of the `rails new` command. Since `rails new` had already been run with full defaults, this was moot. More importantly, it would have been *wrong*: Devise uses Action Mailer for password reset and confirmation emails. Having Action Mailer installed is correct for this project. The lesson: don't reflexively skip Action Mailer on projects that will use Devise.

---

### Decisions

**Decision: Pivot the scaffold rather than start fresh**

> Q: Should we delete the Ledger-L5 repo and run `rails new ledger_l5` from scratch?
> A: No. At Phase 1, the only app-name-specific content is in five files (see Pattern above). Starting fresh would re-run `bundle install`, re-download the Solid Stack, and lose the committed Phase 0/1 learning log entries. Renaming in-place took ~10 minutes and preserved the full git history and doc structure.

**Decision: Devise `Operator` model, not `User`**

> Q: Why name the Devise model `Operator` instead of `User`?
> A: Ledger-L5 has two distinct actor types: `Operator` (internal billing team, Devise-authenticated, manages dashboard) and `Tenant` (external customer, identified by API key, never logs in). Naming the Devise model `User` would create ambiguity — "is this user a tenant or an operator?" — in every conversation and every query. `Operator` is unambiguous.

**Decision: UUID PKs across all domain tables**

> Q: Why not default bigint PKs for internal tables like `tenant_balances`?
> A: Consistency beats convenience. If `tenants.id` is a UUID, then `tenant_balances.tenant_id` is a UUID foreign key. Mixing UUID PKs on some tables and bigint on others creates type mismatches in joins and mental overhead when writing migrations. UUID everywhere is a one-time decision that pays compound interest.

**Decision: Separate `entitlements` table from `tenant_balances`**

> Q: Why not just add `throttled` to `tenant_balances`?
> A: `tenant_balances` is write-heavy — updated atomically on every `AggregateUsageJob`. `entitlements` is read-heavy — polled by three pipeline services on every request. Separating them means entitlement reads never contend with balance update row locks. It also makes the enforcement contract explicit: `entitlements` is the canonical throttle state; `tenant_balances` is the running counter.

---

## Phase 3 — DB Create + Migrations

**Date:** 2026-06-03
**Scope:** `db:create`, generate and run 7 migrations (tenants, api_keys, usage_events, tenant_balances, entitlements, invoices, operators); all UUID PKs.

---

### Patterns

**Pattern: `id: :uuid, default: -> { "gen_random_uuid()" }` on `create_table`**

> Q: How do you declare a UUID primary key in a Rails migration?
> A: Pass `id: :uuid, default: -> { "gen_random_uuid()" }` to `create_table`. The lambda wraps the Postgres function call so Rails emits it as SQL rather than evaluating it in Ruby. `gen_random_uuid()` is a Postgres built-in (pgcrypto extension, available by default in Postgres 13+). Without the `default:` option, Rails would not auto-populate the PK — every INSERT would need an explicit UUID.

**Pattern: `type: :uuid` on `t.references` when the parent table uses UUID PKs**

> Q: If `tenants.id` is a UUID, what changes about the `t.references :tenant` line?
> A: You must add `type: :uuid`. Without it, `t.references :tenant` creates a `tenant_id bigint` column, which can't hold a foreign key to a UUID PK. Rails won't infer the FK type from the parent table — you have to be explicit.

**Pattern: Partial unique index on `stripe_invoice_id`**

> Q: `stripe_invoice_id` is nullable — can you still enforce uniqueness?
> A: Yes, with a partial index: `add_index :invoices, :stripe_invoice_id, unique: true, where: "stripe_invoice_id IS NOT NULL"`. A standard unique index would treat two `NULL` rows as duplicates (Postgres treats NULLs as not equal in unique indexes, but it's cleaner to be explicit). The `where:` clause only indexes non-null rows.

---

### Anti-Patterns

**Anti-Pattern: Adding `t.uuid :id` as a column when `id: :uuid` is the correct approach**

> Q: The generator emitted `t.uuid :id` inside the `create_table` block — isn't that right?
> A: No. `t.uuid :id` adds a column named `id` of type UUID but doesn't make it the primary key. The correct approach is `create_table :name, id: :uuid, default: -> { "gen_random_uuid()" }` — this tells Rails that the PK itself is a UUID column. Passing `id: :uuid` at the table level also suppresses the default bigserial PK that Rails would otherwise create.

---

### Challenges

**Challenge: `sudo` unavailable for `createuser` — postgres role must be created by user**

Rails' `db:create` requires a PostgreSQL role matching the OS user (`amanda`). This role didn't exist. Creating it requires `sudo -u postgres createuser --superuser amanda`, which needs an interactive terminal for the sudo password. The non-interactive tool shell blocked this. Workaround: user ran it manually via `! sudo -u postgres createuser --superuser amanda`.

This is the same recurring WSL2 constraint from Phase 0: anything requiring `sudo` must be delegated to the user.

**Challenge: Neon provides a pooled URL by default — wrong for Rails**

The Neon dashboard's "Connection string" button copies the PgBouncer pooled URL (hostname contains `-pooler`). Using it with Rails causes silent failures: Solid Queue's advisory locks are dropped mid-transaction, and prepared statements can misfire. The fix is to remove `-pooler` from the hostname to get the direct connection. Neon labels this the "Direct" connection in the connection details panel, but it's easy to miss.

**Challenge: rbenv Ruby not on PATH in the tool shell**

Running `bin/rails db:create` failed with "ruby not found" because the tool shell doesn't load `.bash_profile` / `.zprofile` where rbenv's init is configured. Fix: explicitly export the rbenv paths at the top of every shell command — `export PATH="$HOME/.rbenv/bin:$HOME/.rbenv/shims:$PATH" && eval "$(rbenv init -)"`. This is required for every `rails`/`bundle exec` command in this environment.

---

### Decisions

**Decision: `precision: 12, scale: 4` on `quantity` and `current_usage` decimal columns**

> Q: Why not just `t.decimal :quantity`?
> A: Unqualified `decimal` in Postgres maps to arbitrary-precision `NUMERIC`, which is correct but imposes no storage hint. Explicit `precision: 12, scale: 4` gives Postgres a fixed-point column (up to 99,999,999.9999 with four decimal places). This is sufficient for metering quantities (API calls, tokens, GB) and avoids floating-point precision loss. Billing math on floats is an anti-pattern.

**Decision: Neon over Railway-native Postgres**

> Q: Railway offers a built-in Postgres add-on — why use Neon instead?
> A: Neon is serverless and branch-aware: each git branch can get its own database branch (useful for preview deploys). It also has a generous free tier and the same DATABASE_URL convention, so the Rails config is identical. For a portfolio project the operational difference is negligible; Neon's branching story is the differentiator. Same direct connection string is used across all environments (dev, test, prod) — `DATABASE_URL` in `.env` locally, env var on Railway.

**Decision: Direct connection string, not the pooled (PgBouncer) URL**

> Q: Neon offers a pooled connection via PgBouncer — why use the direct one?
> A: Solid Queue uses `pg_try_advisory_lock` for job processing. PgBouncer in transaction mode does not support advisory locks (the lock is released when the transaction ends, defeating the purpose). Rails also uses prepared statements by default, which PgBouncer transaction mode can silently break. The direct connection string (no `-pooler` in the hostname) avoids both issues. For a portfolio-scale app the connection count on Neon's free tier is fine without pooling.

**Decision: Single Neon database for all environments (dev/test/prod)**

> Q: Shouldn't dev, test, and prod use separate databases?
> A: For a portfolio project with no real users, the risk of a shared database is negligible. Neon branching could provide isolation cheaply, but one database simplifies the setup — one `DATABASE_URL`, no branch management, no separate seed/teardown. RSpec's transactional fixtures still roll back between tests. Revisit if the project acquires real data that must be protected.

**Decision: `null: false, default: 0` on `tenant_balances.current_usage`**

> Q: Why default to 0 rather than allowing NULL for "no events yet"?
> A: NULL in a counter column forces every read to guard against nil before doing arithmetic. A zero default makes the balance immediately usable: `tenant.balance.current_usage + event.quantity` never raises a nil error. NULL is semantically wrong here — zero usage is a valid, meaningful state, not "unknown".

**Decision: `index: { unique: true }` on `tenant_id` for `tenant_balances` and `entitlements`**

> Q: Why a unique index on the foreign key, not just a regular index?
> A: Both tables enforce a one-row-per-tenant invariant — one balance row, one entitlement row. A unique index makes the database enforce this, not just application code. Without it, a race condition in `AggregateUsageJob` (two jobs for the same tenant starting simultaneously) could INSERT two balance rows, breaking the atomic UPDATE pattern entirely.

---

## Phase 4 — `ApiKeyAuthenticatable` + `Tenant` / `ApiKey` Models

**Date:** 2026-06-03
**Scope:** `Tenant` and `ApiKey` ActiveRecord models; bcrypt-based API key token scheme; `ApiKeyAuthenticatable` controller concern; model specs.

---

### Patterns

**Pattern: `{id}.{secret}` token format for bcrypt API keys**

> Q: BCrypt is one-way — how do you look up an ApiKey by token without a full table scan?
> A: The token is structured as `{uuid}.{secret}`. The UUID is the record's primary key (assigned in Ruby before save via `self.id = SecureRandom.uuid`). On authentication, the token is split on `.`: the first part is used to find the record by PK (O(1) indexed lookup), then BCrypt verifies the secret part against the stored digest. No table scan, no extra lookup column needed.

**Pattern: `generate_token` assigns `self.id` before Postgres does**

> Q: Postgres generates UUIDs via `gen_random_uuid()` — how can Ruby assign the id before the INSERT?
> A: Rails allows setting `self.id` in Ruby before save. When the record is inserted, ActiveRecord uses the Ruby-assigned UUID as the PK value, and Postgres's `DEFAULT gen_random_uuid()` is bypassed. This is necessary so the UUID is known in memory before the record exists in the database (needed to build the `{id}.{secret}` token).

**Pattern: `delete_prefix("Bearer ")` for header parsing**

> Q: How should the `Authorization` header be parsed?
> A: `request.headers["Authorization"].to_s.delete_prefix("Bearer ").strip` — `to_s` handles nil (returns `""` rather than raising), `delete_prefix` removes the scheme without risk of stripping too much (unlike `split(" ", 2).last`), and `strip` handles any extra whitespace. Safe to call on any header value including absent ones.

---

### Anti-Patterns

**Anti-Pattern: Using `has_secure_token` for API keys**

> Q: Rails has `has_secure_token` — why not use it?
> A: `has_secure_token` generates a token and stores it **in plaintext** (the column holds the actual token). This means anyone who reads the database sees valid tokens. The project requires BCrypt digests — only the hash is stored, never the token itself. `has_secure_token` is for tokens where plaintext storage is acceptable (e.g., password reset links that expire quickly). Long-lived API keys warrant the extra protection.

**Anti-Pattern: `.dependent(:destroy)` matcher without `shoulda-matchers`**

> Q: Why did `it { is_expected.to have_many(:api_keys).dependent(:destroy) }` fail?
> A: Without the `shoulda-matchers` gem, `have_many` resolves to Ruby's built-in `respond_to?(:many?)` — not an RSpec matcher chain. The `.dependent(:destroy)` call then hits the wrong object and raises `NoMethodError`. Fix: either add `shoulda-matchers` or use plain `respond_to` expectations. Chose the latter to avoid adding a gem for one test idiom.

---

### Challenges

**Challenge: FactoryBot not wired into RSpec by default**

`rspec-rails` and `factory_bot_rails` are installed but the `FactoryBot::Syntax::Methods` include must be added to `RSpec.configure` manually in `spec/rails_helper.rb`. Without it, `create(...)` and `build(...)` are undefined in specs. Adding `config.include FactoryBot::Syntax::Methods` to the config block fixes it.

---

### Decisions

**Decision: `generate_token` is a manual call, not a `before_create` callback**

> Q: Why not call `generate_token` automatically in a `before_create` hook?
> A: The plaintext token must be returned to the caller once and only once. A `before_create` callback has no way to surface a return value — there's nowhere to put it that the caller can access without an instance variable hack. Making it a manual call (`raw = api_key.generate_token; api_key.save!`) keeps the contract explicit: the caller is responsible for capturing the token and presenting it to the user.

**Decision: BCrypt for API key digests, not HMAC-SHA256**

> Q: SHA-256 HMAC is faster and allows lookup-by-hash — why BCrypt?
> A: BCrypt's cost factor makes brute-forcing a leaked digest database expensive even for short secrets. The project spec calls for BCrypt explicitly, and the `{id}.{secret}` token format sidesteps BCrypt's main drawback (no indexed lookup) by using the UUID PK for the lookup. The cost in authentication latency (~10ms) is acceptable for an API that doesn't need sub-millisecond auth.

---

## Phase 5 — `POST /api/v1/usage` Ingestion Endpoint

**Date:** 2026-06-03
**Scope:** `UsageEvent` model; `Api::V1::BaseController`; `Api::V1::UsageController`; route `POST /api/v1/usage`; `usage_events` factory; 8 request specs.

---

### Patterns

**Pattern: Separate `Api::V1::BaseController < ActionController::API` for the API namespace**

> Q: Why not include `ApiKeyAuthenticatable` in `ApplicationController` and skip it for non-API routes?
> A: `ApplicationController` inherits from `ActionController::Base` — it has sessions, CSRF protection, view rendering, and cookie handling. API endpoints don't need any of that and including auth there would bleed API behaviour into operator dashboard routes. Subclassing `ActionController::API` gives a clean, lightweight stack for the API namespace with no CSRF and no view overhead. `ApiKeyAuthenticatable` is included once in `BaseController`; all API controllers inherit it automatically.

**Pattern: `rescue ActiveRecord::RecordNotUnique` for idempotency — not `validate :uniqueness`**

> Q: The `usage_events` table has a unique index on `idempotency_key`. Why not also add `validates :uniqueness_of :idempotency_key` in the model?
> A: `validates :uniqueness` works by querying the database before insert — it's a two-step check-then-write, not atomic. Under concurrent load, two requests with the same key can both pass the validation check and then race to insert, with one raising `RecordNotUnique` anyway. The unique index in Postgres is the real enforcement. Rescuing `ActiveRecord::RecordNotUnique` at the controller level handles the duplicate case atomically and correctly whether or not there's a validation — no double-check needed.

**Pattern: Status 202 (Accepted) instead of 201 (Created) for async ingestion**

> Q: RESTful convention for a successful POST is 201 Created — why 202?
> A: 202 Accepted signals "the request was received and will be processed, but processing is not complete." Usage events are ingested synchronously here, but `AggregateUsageJob` (Phase 5) will process them asynchronously. Using 202 from day one sets the correct contract with callers: the event is stored but aggregation happens later. 201 would imply the resource is immediately queryable in its final state.

---

### Anti-Patterns

**Anti-Pattern: `validate :uniqueness, scope: :tenant_id` on `idempotency_key`**

> Q: Should idempotency keys be unique per-tenant rather than globally?
> A: Per-tenant uniqueness seems reasonable ("each tenant manages their own key space"), but it complicates the contract for callers — a key that's valid for Tenant A might collide on Tenant B if they happened to generate the same UUID. Global uniqueness is simpler to reason about, and UUID-based keys (the recommended format) have negligible collision probability across all tenants. The unique index covers the whole column, not a partial scope.

---

### Challenges

**Challenge: Rack deprecation warning for `:unprocessable_entity` in RSpec matchers**

`have_http_status(:unprocessable_entity)` triggers a Rack warning: "Status code :unprocessable_entity is deprecated and will be removed in a future version of Rack. Please use :unprocessable_content instead." The rspec-rails matcher resolves status symbols via Rack::Utils — and Rack now prefers `:unprocessable_content` (the HTTP 1.1 name used in RFC 7231). Fix: use the numeric status `422` directly in the matcher, which bypasses the symbol resolution entirely and is version-agnostic. Same fix applied in the controller for consistency.

**Challenge: rbenv Ruby not on PATH in the tool shell (recurring)**

Identical to Phase 3's challenge — `bundle exec rspec` fails with "command not found" unless `PATH` is explicitly prefixed with `$HOME/.rbenv/shims:$HOME/.rbenv/bin`. This is a WSL2 tool-shell constraint: `.zprofile` / `.bash_profile` are not sourced. Must be repeated on every session.

---

### Decisions

**Decision: `params.require(:usage_event).permit(...)` — namespace params under `usage_event` key**

> Q: Why not accept flat params (`params[:event_type]`, `params[:quantity]`, etc.)?
> A: Rails Strong Parameters with `require(:usage_event)` mirrors ActiveRecord's conventional `create(usage_event_params)` pattern and signals to callers that the request body should be a JSON object with a `usage_event` wrapper. It also makes the controller consistent with any future form-based routes in the operator dashboard that might POST `usage_event` data. Flat params are fine for tiny APIs but the wrapper is worth the minor caller overhead.

**Decision: `metadata: {}` as `permit(metadata: {})` — open permit for JSONB**

> Q: How do you permit an arbitrary JSONB hash in Strong Parameters?
> A: `permit(metadata: {})` allows any key-value pairs within the `metadata` hash. This is Rails' idiom for open-ended hashes — it's not type-safe but it matches the JSONB column semantics where callers define their own structure. The alternative (enumerating every allowed metadata key) would couple the ingestion API to each caller's domain, which defeats the purpose of a flexible metadata field.

**Decision: `POST /api/v1/usage` (singular resource path) not `/api/v1/usage_events`**

> Q: Rails REST convention would use `usage_events` for the resource name — why `usage`?
> A: From the caller's perspective, the action is "report usage", not "create a usage event record". The path communicates intent; the internal model name is an implementation detail. `POST /api/v1/usage` reads naturally in documentation and in `curl` commands. It also leaves room for `GET /api/v1/usage` (a usage summary endpoint) in a later phase without introducing a separate resource namespace.

---

## Phase 6 — `GET /api/v1/entitlements/:id`

**Date:** 2026-06-05
**Scope:** `Entitlement` model; `Api::V1::EntitlementsController#show`; tenant-scoped 404 guard; composite response (entitlement + plan + balance); 7 request specs.

---

### Patterns

**Pattern: Tenant-scoped 404 guard — deny cross-tenant access without revealing existence**

> Q: The entitlement ID is a UUID in the URL — can't a caller just enumerate other tenants' entitlement IDs?
> A: The controller fetches `current_tenant.entitlement` (association-scoped), then compares that record's ID to the URL param. If the tenant has no entitlement, or if the ID doesn't match, the response is 404 — identical in both cases. This is the *object-level authorization* pattern: never return 403 ("you can't see that") for a resource that belongs to someone else — that leaks existence. A 404 is the correct response, indistinguishable from "no such record."

**Pattern: Composite read response — denormalize at the API boundary**

> Q: The entitlement record doesn't store `plan` or `current_usage` — should we add separate endpoints for those?
> A: No. Pipeline services poll this endpoint to make a throttle decision; they need throttle state, plan tier, and current consumption in one call to avoid multiple round trips. Assembling the response from `entitlement`, `current_tenant.plan`, and `current_tenant.tenant_balance` at the controller level is a deliberate denormalization at the API boundary. The separate tables are still correctly normalized — only the *response* is composite.

---

### Anti-Patterns

**Anti-Pattern: Returning 403 for a cross-tenant entitlement request**

> Q: Should the API return 403 Forbidden when the authenticated tenant tries to access another tenant's entitlement?
> A: No. A 403 tells the caller "this resource exists, but you can't have it." That's information leakage — it confirms the UUID maps to a real record. The correct response is 404, which is indistinguishable from "no record with this ID exists." This is standard practice for multi-tenant APIs and is enforced in the spec's authorization section.

---

### Challenges

**Challenge: Decimal column serialized as String in JSON response**

`TenantBalance#current_usage` is a `decimal(12, 4)` column. When Rails serializes it into a JSON response hash, ActiveRecord returns the value as a Ruby `BigDecimal` object. `render json:` calls `.to_s` on `BigDecimal`, producing `"42.0"` (a string) rather than `42.0` (a number). The spec assertion `eq(42.0)` failed because `"42.0" != 42.0`.

Fix: call `.to_f` on the value before including it in the response hash. `BigDecimal#to_f` returns a Ruby Float, which `render json:` serializes as a JSON number. Alternative: use `as_json` or a serializer — but `.to_f` is sufficient at this precision (4 decimal places fit within Float's 15-16 significant digit precision).

---

### Decisions

**Decision: Fetch entitlement via association (`current_tenant.entitlement`), not `Entitlement.find(params[:id])`**

> Q: Why not just `Entitlement.find(params[:id])` and let it raise `RecordNotFound`?
> A: `Entitlement.find(params[:id])` returns any entitlement in the table, regardless of which tenant owns it. A tenant with a valid API key could read any other tenant's entitlement by guessing or brute-forcing UUIDs. Fetching via `current_tenant.entitlement` scopes the lookup to the authenticated tenant's record — the URL ID is then used only to verify the caller is addressing the right resource, not as the lookup key.

**Decision: `current_usage` defaults to `0` when no `TenantBalance` row exists**

> Q: A new tenant has no `tenant_balance` row — should the response omit `current_usage` or return `null`?
> A: Return `0`. The API contract is "how much usage has this tenant consumed this period." Zero is the correct answer for a tenant who has reported no events. Returning `null` would force every caller to guard against a missing field. The `.to_f` call on `nil` (when `tenant_balance` is absent) conveniently returns `0.0`, making the nil-safe default free.

**Decision: Include `plan` in the entitlement response**

> Q: `plan` is on the `tenants` table, not `entitlements` — should pipeline services fetch it separately?
> A: No. Pipeline services need `plan` to interpret the entitlement (e.g., the `free` plan has a 10k/month limit, `pro` has 1M). Putting `plan` in the response eliminates a second API call and avoids a distributed state sync problem: if a separate `/api/v1/tenant` endpoint existed, callers would need to combine two responses under a lock to avoid acting on a stale plan+throttle combination. One response is atomic.
