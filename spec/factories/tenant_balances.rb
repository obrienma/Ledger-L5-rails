FactoryBot.define do
  factory :tenant_balance do
    tenant
    current_usage { 0.0 }
    period_start { Date.current.beginning_of_month }
    period_end { Date.current.end_of_month }
  end
end
