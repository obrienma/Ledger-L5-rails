require "rails_helper"

RSpec.describe "GET /api/v1/entitlements/:id", type: :request do
  let(:tenant)      { create(:tenant) }
  let(:api_key)     { create(:api_key, tenant: tenant) }
  let(:raw_token)   { api_key.instance_variable_get(:@raw_token) }
  let(:auth_headers) { { "Authorization" => "Bearer #{raw_token}" } }
  let(:entitlement) { create(:entitlement, tenant: tenant) }

  describe "happy path" do
    it "returns 200 with entitlement data" do
      get "/api/v1/entitlements/#{entitlement.id}", headers: auth_headers

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["id"]).to eq(entitlement.id)
      expect(body["throttled"]).to eq(false)
      expect(body["throttled_at"]).to be_nil
      expect(body["plan"]).to eq(tenant.plan)
      expect(body["current_usage"]).to eq(0)
    end

    it "includes current_usage from tenant_balance when present" do
      create(:tenant_balance, tenant: tenant, current_usage: 42.0)

      get "/api/v1/entitlements/#{entitlement.id}", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["current_usage"]).to eq(42.0)
    end

    it "reflects throttled state" do
      throttled_at = 1.hour.ago
      entitlement.update!(throttled: true, throttled_at: throttled_at)

      get "/api/v1/entitlements/#{entitlement.id}", headers: auth_headers

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["throttled"]).to eq(true)
      expect(body["throttled_at"]).to be_present
    end
  end

  describe "authentication" do
    it "returns 401 with no Authorization header" do
      get "/api/v1/entitlements/#{entitlement.id}"

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 with an invalid token" do
      get "/api/v1/entitlements/#{entitlement.id}",
          headers: { "Authorization" => "Bearer bad.token" }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "authorization" do
    it "returns 404 for an entitlement belonging to another tenant" do
      other_entitlement = create(:entitlement, tenant: create(:tenant))

      get "/api/v1/entitlements/#{other_entitlement.id}", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 when the tenant has no entitlement" do
      get "/api/v1/entitlements/#{SecureRandom.uuid}", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
