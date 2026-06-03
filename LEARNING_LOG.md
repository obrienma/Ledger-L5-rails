# WireTrace Learning Log

A running record of patterns learned, anti-patterns avoided, challenges encountered, and design decisions made while building WireTrace with Ruby on Rails 8.

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
> A: `rbenv global` sets the fallback Ruby for the entire user account (writes to `~/.rbenv/version`). `rbenv local` writes a `.ruby-version` file in the current directory — this overrides global for that project. Convention: set global to your primary version; use local for projects that pin a different version. WireTrace will get a `.ruby-version` file when the Rails app is initialized.

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
**Scope:** `rails new . --css=tailwind --database=postgresql` in the WireTrace directory

---

### Patterns

**Pattern: `rails new .` (dot) initializes into the current directory**

> Q: What's the difference between `rails new wire_trace` and `rails new .`?
> A: `rails new wire_trace` creates a new subdirectory named `wire_trace/`. `rails new .` scaffolds into the current directory — useful when the directory already exists (e.g., already created on GitHub and cloned). Rails derives the app name from the directory name. In this case the directory is `WireTrace`, so the app module is named `WireTrace`.

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

> Q: Should you use `--api` because WireTrace has an API endpoint?
> A: No. `--api` strips the middleware and view layer needed for Hotwire (sessions, cookies, flash, ERB rendering). WireTrace is hybrid: an API ingestion endpoint AND a browser dashboard. `--api` is only for pure JSON backends consumed by a separate frontend.

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

## Phase 2 — Project Pivot: WireTrace → TallyWire

**Date:** 2026-06-03
**Scope:** Rename app from WireTrace (telemetry) to TallyWire (metering & invoicing). Add Devise, Stripe, RSpec, FactoryBot.

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

> Q: Should we delete the WireTrace repo and run `rails new tally_wire` from scratch?
> A: No. At Phase 1, the only app-name-specific content is in five files (see Pattern above). Starting fresh would re-run `bundle install`, re-download the Solid Stack, and lose the committed Phase 0/1 learning log entries. Renaming in-place took ~10 minutes and preserved the full git history and doc structure.

**Decision: Devise `Operator` model, not `User`**

> Q: Why name the Devise model `Operator` instead of `User`?
> A: TallyWire has two distinct actor types: `Operator` (internal billing team, Devise-authenticated, manages dashboard) and `Tenant` (external customer, identified by API key, never logs in). Naming the Devise model `User` would create ambiguity — "is this user a tenant or an operator?" — in every conversation and every query. `Operator` is unambiguous.

**Decision: UUID PKs across all domain tables**

> Q: Why not default bigint PKs for internal tables like `tenant_balances`?
> A: Consistency beats convenience. If `tenants.id` is a UUID, then `tenant_balances.tenant_id` is a UUID foreign key. Mixing UUID PKs on some tables and bigint on others creates type mismatches in joins and mental overhead when writing migrations. UUID everywhere is a one-time decision that pays compound interest.

**Decision: Separate `entitlements` table from `tenant_balances`**

> Q: Why not just add `throttled` to `tenant_balances`?
> A: `tenant_balances` is write-heavy — updated atomically on every `AggregateUsageJob`. `entitlements` is read-heavy — polled by three pipeline services on every request. Separating them means entitlement reads never contend with balance update row locks. It also makes the enforcement contract explicit: `entitlements` is the canonical throttle state; `tenant_balances` is the running counter.
