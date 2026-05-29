class OutboundEvent < ApplicationRecord
  belongs_to :organization
  belongs_to :replayed_from_outbound_event, class_name: "OutboundEvent", optional: true
  has_many :replayed_outbound_events, class_name: "OutboundEvent", foreign_key: :replayed_from_outbound_event_id,
                                      inverse_of: :replayed_from_outbound_event, dependent: :nullify

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

  scope :dead_lettered, -> { failed.order(failed_at: :asc, created_at: :asc) }
  scope :stale_processing, ->(timeout) {
    processing.where("processing_started_at < ?", Time.current - timeout)
  }

  def delivery_payload
    {
      id: id,
      event_type: event_type,
      aggregate_type: aggregate_type,
      aggregate_id: aggregate_id,
      organization_id: organization_id,
      idempotency_key: idempotency_key,
      correlation_id: correlation_id,
      replayed_from_outbound_event_id: replayed_from_outbound_event_id,
      payload: payload,
      created_at: created_at&.iso8601
    }.compact
  end
end
