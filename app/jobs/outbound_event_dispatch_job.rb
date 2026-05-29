class OutboundEventDispatchJob < ApplicationJob
  class UnsupportedEventType < StandardError; end

  queue_as :default
  MAX_ATTEMPTS = 5
  BASE_RETRY_DELAY = 30.seconds

  SUPPORTED_EVENT_TYPES = %w[
    organization.bootstrapped
    membership.created
    membership.updated
    membership.token_revoked
    membership.token_rotated
    ticket.created
    ticket.updated
  ].freeze

  def perform(outbound_event_id)
    event = OutboundEvent.find(outbound_event_id)
    return if event.dispatched?
    return if event.pending? && event.next_attempt_at.present? && event.next_attempt_at.future?

    raise UnsupportedEventType, "Unsupported event type #{event.event_type}" unless SUPPORTED_EVENT_TYPES.include?(event.event_type)

    event.update!(
      status: "processing",
      processing_started_at: Time.current,
      attempts_count: event.attempts_count + 1,
      last_error: nil,
      next_attempt_at: nil
    )

    self.class.deliver(event)

    event.update!(
      status: "dispatched",
      dispatched_at: Time.current,
      processing_started_at: nil,
      last_error: nil
    )

    Observability::MetricsRegistry.record_outbound(
      event_type: event.event_type,
      status: event.status
    )

    Rails.logger.info(
      message: "outbound_event_dispatched",
      event_id: event.id,
      event_type: event.event_type,
      organization_id: event.organization_id
    )
  rescue UnsupportedEventType => error
    mark_unsupported_event(outbound_event_id, error)
    raise
  rescue StandardError => error
    schedule_retry_or_failure(outbound_event_id, error)
    raise
  end

  def self.deliver(_event)
    true
  end

  private

  def mark_unsupported_event(outbound_event_id, error)
    event = OutboundEvent.find_by(id: outbound_event_id)
    return if event.nil?

    event.update_columns(
      status: "failed",
      attempts_count: event.attempts_count + 1,
      last_error: error.message,
      processing_started_at: nil,
      next_attempt_at: nil,
      updated_at: Time.current
    )

    Observability::MetricsRegistry.record_outbound(
      event_type: event.event_type,
      status: event.status
    )
  end

  def schedule_retry_or_failure(outbound_event_id, error)
    event = OutboundEvent.find_by(id: outbound_event_id)
    return if event.nil?

    attempts_count = [ event.attempts_count, 1 ].max
    final_failure = attempts_count >= MAX_ATTEMPTS

    event.update_columns(
      status: final_failure ? "failed" : "pending",
      attempts_count: attempts_count,
      last_error: error.message,
      processing_started_at: nil,
      next_attempt_at: final_failure ? nil : retry_at(attempts_count),
      updated_at: Time.current
    )

    Observability::MetricsRegistry.record_outbound(
      event_type: event.event_type,
      status: event.status
    )
  end

  def retry_at(attempts_count)
    Time.current + (BASE_RETRY_DELAY * (2**(attempts_count - 1)))
  end
end
