FactoryBot.define do
  factory :entitlement do
    tenant
    throttled { false }
    throttled_at { nil }
  end
end
