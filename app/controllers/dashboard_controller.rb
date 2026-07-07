class DashboardController < ApplicationController
  before_action :authenticate_operator!

  def index
    @tenants = Tenant.includes(:tenant_balance, :entitlement).order(:name)
  end
end
