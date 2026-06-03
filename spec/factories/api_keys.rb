FactoryBot.define do
  factory :api_key do
    tenant
    sequence(:name) { |n| "Key #{n}" }
    active { true }

    # generate_token assigns id + token_digest and returns the plaintext token.
    # Access it via api_key.instance_variable_get(:@raw_token) in tests that
    # need to authenticate.
    after(:build) do |api_key|
      api_key.instance_variable_set(:@raw_token, api_key.generate_token)
    end

    trait :inactive do
      active { false }
    end
  end
end
