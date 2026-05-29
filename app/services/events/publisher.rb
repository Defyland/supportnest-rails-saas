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
        OutboundEventDispatchJob.perform_later(event.id)
      end

      event
    end
  end
end
