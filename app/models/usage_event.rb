class UsageEvent < ApplicationRecord
  belongs_to :tenant

  validates :event_type, presence: true
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :occurred_at, presence: true
  validates :idempotency_key, presence: true
end
