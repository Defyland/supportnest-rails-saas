class OutboundEvent < ApplicationRecord
  belongs_to :organization

  enum :status, {
    pending: "pending",
    dispatched: "dispatched",
    failed: "failed"
  }, validate: true

  validates :aggregate_type, :aggregate_id, :event_type, :idempotency_key, :correlation_id, presence: true
  validates :idempotency_key, uniqueness: true
end
