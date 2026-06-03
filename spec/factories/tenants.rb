FactoryBot.define do
  factory :tenant do
    sequence(:name) { |n| "Tenant #{n}" }
    plan { "free" }
    status { "active" }
  end
end
