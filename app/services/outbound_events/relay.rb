require "socket"

module OutboundEvents
  class Relay
    DEFAULT_BATCH_SIZE = 25
    DEFAULT_PROCESSING_TIMEOUT = 5.minutes

    Result = Data.define(:claimed_count, :dispatched_count, :failed_count, :retried_count)

    def self.call!(batch_size: DEFAULT_BATCH_SIZE, worker_id: nil, delivery: WebhookDelivery.new,
                   processing_timeout: DEFAULT_PROCESSING_TIMEOUT)
      new(
        batch_size: batch_size,
        worker_id: worker_id,
        delivery: delivery,
        processing_timeout: processing_timeout
      ).call!
    end

    def initialize(batch_size:, worker_id:, delivery:, processing_timeout:)
      @batch_size = batch_size
      @worker_id = worker_id || "relay-#{Socket.gethostname}-#{Process.pid}"
      @delivery = delivery
      @processing_timeout = processing_timeout
    end

    def call!
      recover_stale_processing!
      events = claim_batch
      counts = Hash.new(0)

      events.each do |event|
        dispatch_claimed(event, counts)
      end

      Result.new(
        claimed_count: events.count,
        dispatched_count: counts[:dispatched],
        failed_count: counts[:failed],
        retried_count: counts[:retried]
      )
    end

    private

    def claim_batch
      OutboundEvent.transaction do
        events = OutboundEvent.due_for_dispatch
                              .lock("FOR UPDATE SKIP LOCKED")
                              .limit(@batch_size)
                              .to_a
        dispatcher = Dispatcher.new(delivery: @delivery, worker_id: @worker_id)
        events.each { |event| dispatcher.claim!(event) }
        events
      end
    end

    def dispatch_claimed(event, counts)
      Dispatcher.new(delivery: @delivery, worker_id: @worker_id).dispatch!(event, claimed: true)
      counts[:dispatched] += 1
    rescue Dispatcher::UnsupportedEventType
      counts[:failed] += 1
    rescue StandardError
      event.reload.failed? ? counts[:failed] += 1 : counts[:retried] += 1
    end

    def recover_stale_processing!
      OutboundEvent.stale_processing(@processing_timeout).update_all(
        status: "pending",
        processing_started_at: nil,
        next_attempt_at: Time.current,
        last_error: "processing timeout after #{@processing_timeout.to_i} seconds",
        relay_worker_id: nil,
        updated_at: Time.current
      )
    end
  end
end
