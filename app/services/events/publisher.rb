module Events
  class Publisher
    def self.publish!(organization:, aggregate:, event_type:, payload:)
      event = OutboundEvent.create!(
        organization: organization,
        aggregate_type: aggregate.class.name,
        aggregate_id: aggregate.id,
        event_type: event_type,
        payload: payload,
        correlation_id: Current.correlation_id || SecureRandom.uuid,
        idempotency_key: "#{event_type}:#{aggregate.class.name}:#{aggregate.id}:#{SecureRandom.uuid}"
      )

      ActiveRecord.after_all_transactions_commit do
        OutboundEventDispatchJob.perform_later(event.id) if dispatch_with_active_job?
      end

      event
    end

    def self.dispatch_with_active_job?
      dispatch_mode == "active_job"
    end

    def self.dispatch_mode
      ENV.fetch("OUTBOX_DISPATCH_MODE") do
        default_dispatch_mode
      end
    end

    def self.default_dispatch_mode(environment = Rails.env)
      environment.production? ? "relay" : "active_job"
    end
  end
end
