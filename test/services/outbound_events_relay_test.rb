require "test_helper"

class OutboundEventsRelayTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    cleanup_records!
  end

  teardown do
    cleanup_records!
  end

  test "dispatches each due event once across concurrent relay workers" do
    skip_unless_postgresql!

    organization = Organization.create!(name: "Acme", slug: unique_slug("relay"))
    events = 10.times.map do |index|
      create_event(organization: organization, idempotency_key: "relay-event-#{index}")
    end
    delivery = RecordingDelivery.new

    threads = 2.times.map do |index|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          OutboundEvents::Relay.call!(batch_size: 5, worker_id: "relay-worker-#{index}", delivery: delivery)
        end
      end
    end
    threads.each(&:join)

    assert_equal events.map(&:id).sort, delivery.delivered_ids.sort
    assert_equal events.count, delivery.delivered_ids.uniq.count
    assert_equal events.count, OutboundEvent.dispatched.count
    assert OutboundEvent.where.not(relay_worker_id: nil).exists?
  end

  test "moves exhausted transient failures to the dead letter queue" do
    organization = Organization.create!(name: "Acme", slug: unique_slug("dead-letter"))
    event = create_event(
      organization: organization,
      idempotency_key: "dead-letter-event",
      attempts_count: OutboundEvents::Dispatcher::MAX_ATTEMPTS - 1
    )

    result = OutboundEvents::Relay.call!(
      batch_size: 1,
      worker_id: "relay-worker-failing",
      delivery: FailingDelivery.new
    )

    assert_equal 1, result.failed_count
    event.reload
    assert_equal "failed", event.status
    assert_equal OutboundEvents::Dispatcher::MAX_ATTEMPTS, event.attempts_count
    assert event.failed_at.present?
    assert_match "temporary outage", event.dead_letter_reason
    assert_nil event.next_attempt_at
  end

  test "requeues stale processing events before claiming due work" do
    organization = Organization.create!(name: "Acme", slug: unique_slug("stale-relay"))
    stale_event = create_event(
      organization: organization,
      idempotency_key: "stale-event",
      status: "processing",
      processing_started_at: 10.minutes.ago
    )

    result = OutboundEvents::Relay.call!(
      batch_size: 1,
      worker_id: "relay-worker-recover",
      delivery: RecordingDelivery.new,
      processing_timeout: 5.minutes
    )

    assert_equal 1, result.claimed_count
    assert_equal "dispatched", stale_event.reload.status
  end

  test "replays failed events as new pending events with lineage" do
    organization = Organization.create!(name: "Acme", slug: unique_slug("replay"))
    event = create_event(
      organization: organization,
      idempotency_key: "failed-event",
      status: "failed",
      failed_at: 1.minute.ago,
      dead_letter_reason: "webhook outage"
    )

    replay = OutboundEvents::Replay.call!(event: event, requested_by: "test-operator")

    assert_equal "pending", replay.status
    assert_equal event, replay.replayed_from_outbound_event
    assert_match(/\Areplay:#{event.id}:/, replay.idempotency_key)
    assert_equal "test-operator", replay.payload.dig("replay", "requested_by")
  end

  private

  def create_event(organization:, idempotency_key:, status: "pending", attempts_count: 0,
                   processing_started_at: nil, failed_at: nil, dead_letter_reason: nil)
    OutboundEvent.create!(
      organization: organization,
      aggregate_type: "Ticket",
      aggregate_id: 1,
      event_type: "ticket.created",
      status: status,
      attempts_count: attempts_count,
      payload: { ticket_id: "TCK-000001" },
      idempotency_key: idempotency_key,
      correlation_id: idempotency_key,
      processing_started_at: processing_started_at,
      failed_at: failed_at,
      dead_letter_reason: dead_letter_reason
    )
  end

  def skip_unless_postgresql!
    return if ActiveRecord::Base.connection.adapter_name == "PostgreSQL"

    skip "PostgreSQL SKIP LOCKED semantics are required for relay concurrency"
  end

  def cleanup_records!
    AuditLog.delete_all
    OutboundEvent.update_all(replayed_from_outbound_event_id: nil)
    OutboundEvent.delete_all
    Ticket.delete_all
    Membership.delete_all
    Organization.delete_all
  end

  class RecordingDelivery
    attr_reader :delivered_ids

    def initialize
      @mutex = Mutex.new
      @delivered_ids = []
    end

    def deliver(event)
      sleep 0.02
      @mutex.synchronize { @delivered_ids << event.id }
    end
  end

  class FailingDelivery
    def deliver(_event)
      raise "temporary outage"
    end
  end
end
