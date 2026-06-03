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
