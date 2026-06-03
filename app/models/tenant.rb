class Tenant < ApplicationRecord
  has_many :api_keys, dependent: :destroy
  has_one :tenant_balance, dependent: :destroy
  has_one :entitlement, dependent: :destroy
  has_many :invoices, dependent: :destroy
  has_many :usage_events, dependent: :destroy

  enum :plan, { free: "free", starter: "starter", pro: "pro", enterprise: "enterprise" }
  enum :status, { active: "active", suspended: "suspended", cancelled: "cancelled" }

  validates :name, presence: true
end
