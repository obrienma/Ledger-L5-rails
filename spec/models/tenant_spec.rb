require "rails_helper"

RSpec.describe Tenant, type: :model do
  describe "validations" do
    it "is valid with required attributes" do
      expect(build(:tenant)).to be_valid
    end

    it "is invalid without a name" do
      expect(build(:tenant, name: nil)).not_to be_valid
    end
  end

  describe "enums" do
    it "defaults to free plan" do
      tenant = create(:tenant)
      expect(tenant.plan).to eq("free")
    end

    it "defaults to active status" do
      tenant = create(:tenant)
      expect(tenant.status).to eq("active")
    end
  end

  describe "associations" do
    let(:tenant) { build(:tenant) }

    it { expect(tenant).to respond_to(:api_keys) }
    it { expect(tenant).to respond_to(:usage_events) }
    it { expect(tenant).to respond_to(:tenant_balance) }
    it { expect(tenant).to respond_to(:entitlement) }
    it { expect(tenant).to respond_to(:invoices) }
  end
end
