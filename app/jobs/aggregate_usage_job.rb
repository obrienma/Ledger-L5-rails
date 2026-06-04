class AggregateUsageJob < ApplicationJob
  queue_as :default

  def perform(tenant_id)
    period_start = Date.current.beginning_of_month
    period_end   = Date.current.end_of_month

    TenantBalance.find_or_create_by!(tenant_id: tenant_id) do |b|
      b.period_start  = period_start
      b.period_end    = period_end
      b.current_usage = 0
    end

    TenantBalance.where(tenant_id: tenant_id).update_all(
      [
        <<~SQL.squish,
          current_usage = (
            SELECT COALESCE(SUM(quantity), 0)
            FROM usage_events
            WHERE tenant_id = ?
              AND occurred_at >= ?
              AND occurred_at < ?
          ),
          updated_at = NOW()
        SQL
        tenant_id, period_start, period_end + 1.day
      ]
    )
  end
end
