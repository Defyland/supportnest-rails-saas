class OutboundEventDispatchJob < ApplicationJob
  queue_as :default

  SUPPORTED_EVENT_TYPES = %w[
    organization.bootstrapped
    membership.created
    membership.updated
    ticket.created
    ticket.updated
  ].freeze

  def perform(outbound_event_id)
    event = OutboundEvent.find(outbound_event_id)
    raise ArgumentError, "Unsupported event type #{event.event_type}" unless SUPPORTED_EVENT_TYPES.include?(event.event_type)

    event.update!(
      status: "dispatched",
      dispatched_at: Time.current,
      attempts_count: event.attempts_count + 1,
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
  rescue StandardError => error
    mark_failure(outbound_event_id, error)
    raise
  end

  private

  def mark_failure(outbound_event_id, error)
    event = OutboundEvent.find_by(id: outbound_event_id)
    return if event.nil?

    event.update_columns(
      status: "failed",
      attempts_count: event.attempts_count + 1,
      last_error: error.message,
      updated_at: Time.current
    )

    Observability::MetricsRegistry.record_outbound(
      event_type: event.event_type,
      status: event.status
    )
  end
end
