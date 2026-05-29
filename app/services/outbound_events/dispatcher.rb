module OutboundEvents
  class Dispatcher
    class UnsupportedEventType < StandardError; end

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

    def initialize(delivery: WebhookDelivery.new, worker_id: nil)
      @delivery = delivery
      @worker_id = worker_id
    end

    def dispatch!(event, claimed: false)
      return :already_dispatched if event.dispatched?
      return :dead_lettered if event.failed?
      return :not_due if event.pending? && event.next_attempt_at.present? && event.next_attempt_at.future?

      unless SUPPORTED_EVENT_TYPES.include?(event.event_type)
        move_to_dead_letter!(event, UnsupportedEventType.new("Unsupported event type #{event.event_type}"), claimed: claimed)
        raise UnsupportedEventType, "Unsupported event type #{event.event_type}"
      end

      claim!(event) unless claimed || event.processing?

      @delivery.deliver(event)
      mark_dispatched!(event)
      :dispatched
    rescue UnsupportedEventType
      raise
    rescue StandardError => error
      schedule_retry_or_dead_letter!(event, error)
      raise
    end

    def claim!(event)
      event.update!(
        status: "processing",
        processing_started_at: Time.current,
        attempts_count: event.attempts_count + 1,
        last_error: nil,
        next_attempt_at: nil,
        failed_at: nil,
        dead_letter_reason: nil,
        relay_worker_id: @worker_id
      )
    end

    private

    def mark_dispatched!(event)
      event.update!(
        status: "dispatched",
        dispatched_at: Time.current,
        processing_started_at: nil,
        last_error: nil,
        failed_at: nil,
        dead_letter_reason: nil
      )

      record_metric(event)
      Rails.logger.info(
        message: "outbound_event_dispatched",
        event_id: event.id,
        event_type: event.event_type,
        organization_id: event.organization_id
      )
    end

    def move_to_dead_letter!(event, error, claimed:)
      attempts_count = claimed || event.processing? ? event.attempts_count : event.attempts_count + 1
      event.update_columns(
        status: "failed",
        attempts_count: attempts_count,
        last_error: error.message,
        failed_at: Time.current,
        dead_letter_reason: error.message,
        processing_started_at: nil,
        next_attempt_at: nil,
        updated_at: Time.current
      )

      record_metric(event.reload)
    end

    def schedule_retry_or_dead_letter!(event, error)
      event.reload
      attempts_count = [ event.attempts_count, 1 ].max
      final_failure = attempts_count >= MAX_ATTEMPTS

      event.update_columns(
        status: final_failure ? "failed" : "pending",
        attempts_count: attempts_count,
        last_error: error.message,
        failed_at: final_failure ? Time.current : nil,
        dead_letter_reason: final_failure ? error.message : nil,
        processing_started_at: nil,
        next_attempt_at: final_failure ? nil : retry_at(attempts_count),
        updated_at: Time.current
      )

      record_metric(event.reload)
    end

    def retry_at(attempts_count)
      Time.current + (BASE_RETRY_DELAY * (2**(attempts_count - 1)))
    end

    def record_metric(event)
      Observability::MetricsRegistry.record_outbound(
        event_type: event.event_type,
        status: event.status
      )
    end
  end
end
