require "test_helper"

class OutboundEventDispatchJobTest < ActiveSupport::TestCase
  test "marks a supported outbound event as dispatched" do
    organization = Organization.create!(name: "Acme", slug: unique_slug("acme"))
    event = OutboundEvent.create!(
      organization: organization,
      aggregate_type: "Ticket",
      aggregate_id: 1,
      event_type: "ticket.created",
      status: "pending",
      payload: { ticket_id: "TCK-000001" },
      idempotency_key: "event-1",
      correlation_id: "corr-1"
    )

    OutboundEventDispatchJob.perform_now(event.id)

    assert_equal "dispatched", event.reload.status
    assert event.dispatched_at.present?
    assert_equal 1, event.attempts_count
  end

  test "marks unsupported outbound events as failed" do
    organization = Organization.create!(name: "Acme", slug: unique_slug("acme"))
    event = OutboundEvent.create!(
      organization: organization,
      aggregate_type: "Ticket",
      aggregate_id: 1,
      event_type: "ticket.unsupported",
      status: "pending",
      payload: { ticket_id: "TCK-000001" },
      idempotency_key: "event-2",
      correlation_id: "corr-2"
    )

    assert_raises(OutboundEventDispatchJob::UnsupportedEventType) do
      OutboundEventDispatchJob.perform_now(event.id)
    end

    assert_equal "failed", event.reload.status
    assert_match "Unsupported event type", event.last_error
  end

  test "schedules retry with backoff when dispatch delivery fails" do
    organization = Organization.create!(name: "Acme", slug: unique_slug("acme"))
    event = OutboundEvent.create!(
      organization: organization,
      aggregate_type: "Ticket",
      aggregate_id: 1,
      event_type: "ticket.created",
      status: "pending",
      payload: { ticket_id: "TCK-000001" },
      idempotency_key: "event-retry",
      correlation_id: "corr-retry"
    )

    assert_raises RuntimeError do
      with_failing_delivery do
        OutboundEventDispatchJob.perform_now(event.id)
      end
    end

    event.reload
    assert_equal "pending", event.status
    assert_equal 1, event.attempts_count
    assert event.next_attempt_at.future?
    assert_nil event.processing_started_at
    assert_match "temporary outage", event.last_error
  end

  test "marks event failed after maximum retry attempts" do
    organization = Organization.create!(name: "Acme", slug: unique_slug("acme"))
    event = OutboundEvent.create!(
      organization: organization,
      aggregate_type: "Ticket",
      aggregate_id: 1,
      event_type: "ticket.created",
      status: "pending",
      attempts_count: OutboundEventDispatchJob::MAX_ATTEMPTS - 1,
      payload: { ticket_id: "TCK-000001" },
      idempotency_key: "event-final-failure",
      correlation_id: "corr-final-failure"
    )

    assert_raises RuntimeError do
      with_failing_delivery do
        OutboundEventDispatchJob.perform_now(event.id)
      end
    end

    event.reload
    assert_equal "failed", event.status
    assert_equal OutboundEventDispatchJob::MAX_ATTEMPTS, event.attempts_count
    assert_nil event.next_attempt_at
    assert_match "temporary outage", event.last_error
  end

  private

  def with_failing_delivery
    original_deliver = OutboundEventDispatchJob.method(:deliver)
    OutboundEventDispatchJob.define_singleton_method(:deliver) { |_| raise "temporary outage" }

    yield
  ensure
    OutboundEventDispatchJob.define_singleton_method(:deliver, original_deliver)
  end
end
