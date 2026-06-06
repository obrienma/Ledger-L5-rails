module Api
  module V1
    class EntitlementsController < BaseController
      def show
        entitlement = current_tenant.entitlement

        return render json: { error: "Not found" }, status: :not_found unless entitlement
        return render json: { error: "Not found" }, status: :not_found unless entitlement.id.to_s == params[:id]

        render json: {
          id: entitlement.id,
          throttled: entitlement.throttled,
          throttled_at: entitlement.throttled_at,
          plan: current_tenant.plan,
          current_usage: current_tenant.tenant_balance&.current_usage.to_f
        }
      end
    end
  end
end
