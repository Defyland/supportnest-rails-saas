class OutboundEvent < ApplicationRecord
  belongs_to :organization

  enum :status, {
    pending: "pending",
    processing: "processing",
    dispatched: "dispatched",
    failed: "failed"
  }, validate: true

  validates :aggregate_type, :aggregate_id, :event_type, :idempotency_key, :correlation_id, presence: true
  validates :idempotency_key, uniqueness: true

  scope :due_for_dispatch, -> {
    pending.where("next_attempt_at IS NULL OR next_attempt_at <= ?", Time.current).order(:created_at)
  }
end
