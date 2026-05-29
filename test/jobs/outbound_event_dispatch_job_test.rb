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

    assert_raises(ArgumentError) do
      OutboundEventDispatchJob.perform_now(event.id)
    end

    assert_equal "failed", event.reload.status
    assert_match "Unsupported event type", event.last_error
  end
end
