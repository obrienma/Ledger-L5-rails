require "rails_helper"

RSpec.describe "GET /", type: :request do
  let(:operator) { create(:operator) }

  describe "authentication" do
    it "redirects to the operator sign-in page when not signed in" do
      get root_path

      expect(response).to redirect_to(new_operator_session_path)
    end
  end

  describe "happy path" do
    before { sign_in operator }

    it "returns 200 and renders the tenant list" do
      tenant = create(:tenant, name: "Acme Corp", plan: "pro")
      create(:tenant_balance, tenant: tenant, current_usage: 42.0)
      create(:entitlement, tenant: tenant)

      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Acme Corp")
      expect(response.body).to include("pro")
      expect(response.body).to include("42")
      expect(response.body).to include("OK")
    end

    it "shows a Throttled badge for a throttled tenant" do
      tenant = create(:tenant, name: "Blocked Inc")
      create(:entitlement, tenant: tenant, throttled: true, throttled_at: 1.hour.ago)

      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Throttled")
    end

    it "shows an empty state when there are no tenants" do
      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No tenants yet.")
    end

    it "defaults current_usage to 0 when a tenant has no TenantBalance" do
      create(:tenant, name: "No Balance Yet")

      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No Balance Yet")
    end
  end
end
