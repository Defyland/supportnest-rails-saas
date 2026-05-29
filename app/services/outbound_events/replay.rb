module OutboundEvents
  class Replay
    def self.call!(event:, requested_by: "operator")
      raise ArgumentError, "only failed outbound events can be replayed" unless event.failed?

      OutboundEvent.create!(
        organization: event.organization,
        aggregate_type: event.aggregate_type,
        aggregate_id: event.aggregate_id,
        event_type: event.event_type,
        status: "pending",
        payload: event.payload.merge(
          "replay" => {
            "requested_by" => requested_by,
            "replayed_from_outbound_event_id" => event.id,
            "requested_at" => Time.current.iso8601
          }
        ),
        idempotency_key: "replay:#{event.id}:#{SecureRandom.uuid}",
        correlation_id: event.correlation_id,
        replayed_from_outbound_event: event
      )
    end
  end
end
