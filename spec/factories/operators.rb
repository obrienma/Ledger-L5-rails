FactoryBot.define do
  factory :operator do
    sequence(:email) { |n| "operator#{n}@example.com" }
    password { "password123" }
  end
end
