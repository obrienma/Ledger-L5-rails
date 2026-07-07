require "rails_helper"

RSpec.describe AggregateUsageJob, type: :job do
  let(:tenant) { create(:tenant) }

  describe "#perform" do
    context "when usage events exist in the current period" do
      before do
        create(:usage_event, tenant: tenant, quantity: 3.0, occurred_at: Time.current)
        create(:usage_event, tenant: tenant, quantity: 2.5, occurred_at: Time.current)
      end

      it "creates a TenantBalance with current_usage equal to the sum" do
        described_class.perform_now(tenant.id.to_s)

        balance = TenantBalance.find_by!(tenant_id: tenant.id)
        expect(balance.current_usage).to eq(5.5)
      end

      it "sets period_start and period_end to the current calendar month" do
        described_class.perform_now(tenant.id.to_s)

        balance = TenantBalance.find_by!(tenant_id: tenant.id)
        expect(balance.period_start).to eq(Date.current.beginning_of_month)
        expect(balance.period_end).to eq(Date.current.end_of_month)
      end
    end

    context "when no usage events exist" do
      it "creates a TenantBalance with current_usage of 0" do
        described_class.perform_now(tenant.id.to_s)

        balance = TenantBalance.find_by!(tenant_id: tenant.id)
        expect(balance.current_usage).to eq(0)
      end
    end

    context "idempotency" do
      before do
        create(:usage_event, tenant: tenant, quantity: 4.0, occurred_at: Time.current)
      end

      it "produces exactly one TenantBalance on repeated runs" do
        described_class.perform_now(tenant.id.to_s)
        described_class.perform_now(tenant.id.to_s)

        expect(TenantBalance.where(tenant_id: tenant.id).count).to eq(1)
      end

      it "reflects the correct total after repeated runs" do
        described_class.perform_now(tenant.id.to_s)
        described_class.perform_now(tenant.id.to_s)

        expect(TenantBalance.find_by!(tenant_id: tenant.id).current_usage).to eq(4.0)
      end
    end

    context "when events are outside the current period" do
      before do
        create(:usage_event, tenant: tenant, quantity: 10.0, occurred_at: 2.months.ago)
      end

      it "excludes out-of-period events from current_usage" do
        described_class.perform_now(tenant.id.to_s)

        balance = TenantBalance.find_by!(tenant_id: tenant.id)
        expect(balance.current_usage).to eq(0)
      end
    end

    context "when events belong to a different tenant" do
      let(:other_tenant) { create(:tenant) }

      before do
        create(:usage_event, tenant: other_tenant, quantity: 99.0, occurred_at: Time.current)
      end

      it "does not include other tenants' events" do
        described_class.perform_now(tenant.id.to_s)

        balance = TenantBalance.find_by!(tenant_id: tenant.id)
        expect(balance.current_usage).to eq(0)
      end
    end

    context "Turbo Stream broadcast" do
      it "broadcasts a replace targeting the tenant's row on the dashboard stream" do
        create(:usage_event, tenant: tenant, quantity: 3.0, occurred_at: Time.current)

        expect { described_class.perform_now(tenant.id.to_s) }
          .to have_broadcasted_to("dashboard").with { |html|
            expect(html).to include("tenant_#{tenant.id}")
            expect(html).to include('action="replace"')
          }
      end

      it "broadcasts fresh current_usage, not a stale pre-update value" do
        create(:usage_event, tenant: tenant, quantity: 7.0, occurred_at: Time.current)

        expect { described_class.perform_now(tenant.id.to_s) }
          .to have_broadcasted_to("dashboard").with { |html|
            expect(html).to include("7")
          }
      end
    end
  end
end
