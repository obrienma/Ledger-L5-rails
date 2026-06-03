# ADR 0008 — RSpec + FactoryBot Over Rails Default Minitest

**Status:** Accepted
**Date:** 2026-06-03

---

## Context

Rails ships with Minitest as the default test framework. RSpec is the dominant alternative in the Rails ecosystem, particularly for applications with complex domain logic.

TallyWire has specific testing requirements that inform this decision:

1. **Idempotency testing** — `POST /api/v1/usage` must handle concurrent duplicate `idempotency_key` submissions without double-counting. Testing this requires spawning multiple threads and asserting on race conditions at the DB layer.
2. **Tenant plan variants** — Tests need to set up tenants in various plan/status combinations (free, throttled, overaged). Factory inheritance makes this significantly less verbose.
3. **Shared example groups** — The API key authentication `before_action` is used across multiple controllers. RSpec shared examples allow a single spec to be run against all controllers.

---

## Decision

Use **RSpec 8** (via `rspec-rails`) and **FactoryBot** (via `factory_bot_rails`). Remove Minitest entirely — `test/` directory deleted.

---

## Consequences

**Positive:**

- **Concurrent idempotency spec** is expressible with `Thread.new` blocks and `expect { }.to change(UsageEvent, :count).by(1)` — readable without custom assertion helpers.
- **Factory inheritance** for tenant plans:
  ```ruby
  factory :tenant do
    name { "Acme Corp" }
    plan { :starter }
    status { :active }

    trait :free    { plan { :free } }
    trait :pro     { plan { :pro } }
    trait :throttled { status { :suspended }; association :entitlement, :throttled }
  end
  ```
  A minitest fixture approach would need multiple YAML stanzas or manual setup in each test.
- **Shared examples** for `authenticate_api_request!`:
  ```ruby
  RSpec.shared_examples "requires API key" do
    it "returns 401 with missing Authorization header" do ...  end
    it "returns 401 with invalid token" do ...  end
  end
  ```
- `let` memoization and `subject` blocks reduce repetition in unit specs.

**Negative / Trade-offs:**
- Larger gem footprint than Minitest (which is in stdlib).
- RSpec's `describe`/`context`/`it` DSL is unfamiliar to developers coming only from Minitest.
- Rails generators produce Minitest files by default; `rspec-rails` overrides this, but some generators still need `--no-test-framework` to avoid generating `.._test.rb` stubs.

**Configuration:**
`spec/rails_helper.rb` will include:
```ruby
config.include FactoryBot::Syntax::Methods
config.use_transactional_fixtures = true
```

**Laravel analogy:**
- RSpec ↔ PHPUnit/Pest with describe blocks and `beforeEach`
- FactoryBot ↔ Laravel Model Factories with states/traits
