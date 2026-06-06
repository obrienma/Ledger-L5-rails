class Entitlement < ApplicationRecord
  belongs_to :tenant

  validates :throttled, inclusion: { in: [true, false] }
end
