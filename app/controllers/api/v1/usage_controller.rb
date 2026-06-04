module Api
  module V1
    class UsageController < BaseController
      def create
        event = current_tenant.usage_events.build(usage_event_params)

        if event.save
          AggregateUsageJob.perform_later(current_tenant.id.to_s)
          render json: { id: event.id }, status: :accepted
        else
          render json: { errors: event.errors.full_messages }, status: 422
        end
      rescue ActiveRecord::RecordNotUnique
        render json: { error: "Duplicate idempotency_key" }, status: :conflict
      end

      private

      def usage_event_params
        params.require(:usage_event).permit(
          :event_type, :quantity, :occurred_at, :idempotency_key,
          metadata: {}
        )
      end
    end
  end
end
