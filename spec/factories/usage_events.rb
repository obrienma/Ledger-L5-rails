FactoryBot.define do
  factory :usage_event do
    tenant
    event_type { "api_call" }
    quantity { 1.0 }
    occurred_at { Time.current }
    sequence(:idempotency_key) { |n| "idem-key-#{n}" }
    metadata { {} }
  end
end
