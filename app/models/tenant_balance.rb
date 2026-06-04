class TenantBalance < ApplicationRecord
  belongs_to :tenant

  validates :period_start, presence: true
  validates :period_end, presence: true
  validates :current_usage, numericality: { greater_than_or_equal_to: 0 }
end
