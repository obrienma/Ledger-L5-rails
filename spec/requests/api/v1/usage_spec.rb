require "rails_helper"

RSpec.describe "POST /api/v1/usage", type: :request do
  let(:tenant) { create(:tenant) }
  let(:api_key) { create(:api_key, tenant: tenant) }
  let(:raw_token) { api_key.instance_variable_get(:@raw_token) }
  let(:auth_headers) { { "Authorization" => "Bearer #{raw_token}" } }

  let(:valid_params) do
    {
      usage_event: {
        event_type: "api_call",
        quantity: 5,
        occurred_at: Time.current.iso8601,
        idempotency_key: SecureRandom.uuid
      }
    }
  end

  describe "happy path" do
    it "returns 202 and the new event id" do
      post "/api/v1/usage", params: valid_params, headers: auth_headers

      expect(response).to have_http_status(:accepted)
      body = response.parsed_body
      expect(body["id"]).to be_present
      expect(UsageEvent.count).to eq(1)
      expect(UsageEvent.last.tenant).to eq(tenant)
    end

    it "persists metadata when provided" do
      params = valid_params.deep_merge(usage_event: { metadata: { region: "us-east" } })

      post "/api/v1/usage", params: params, headers: auth_headers

      expect(response).to have_http_status(:accepted)
      expect(UsageEvent.last.metadata["region"]).to eq("us-east")
    end
  end

  describe "idempotency" do
    it "returns 409 on a duplicate idempotency_key" do
      key = SecureRandom.uuid
      params = valid_params.deep_merge(usage_event: { idempotency_key: key })

      post "/api/v1/usage", params: params, headers: auth_headers
      expect(response).to have_http_status(:accepted)

      post "/api/v1/usage", params: params, headers: auth_headers
      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body["error"]).to match(/duplicate/i)
    end
  end

  describe "authentication" do
    it "returns 401 with no Authorization header" do
      post "/api/v1/usage", params: valid_params

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 with a bad token" do
      post "/api/v1/usage", params: valid_params,
           headers: { "Authorization" => "Bearer bad.token" }

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 with an inactive key" do
      api_key.update!(active: false)

      post "/api/v1/usage", params: valid_params, headers: auth_headers

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "validation" do
    it "returns 422 when event_type is missing" do
      params = valid_params.deep_merge(usage_event: { event_type: nil })

      post "/api/v1/usage", params: params, headers: auth_headers

      expect(response).to have_http_status(422)
      expect(response.parsed_body["errors"]).to be_present
    end

    it "returns 422 when quantity is not positive" do
      params = valid_params.deep_merge(usage_event: { quantity: -1 })

      post "/api/v1/usage", params: params, headers: auth_headers

      expect(response).to have_http_status(422)
    end
  end
end
