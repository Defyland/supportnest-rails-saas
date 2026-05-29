require "test_helper"

class OutboundEventTest < ActiveSupport::TestCase
  test "finds pending events due for dispatch" do
    organization = Organization.create!(name: "Acme", slug: unique_slug("acme"))
    due_event = create_event(organization: organization, idempotency_key: "due", next_attempt_at: 1.minute.ago)
    create_event(organization: organization, idempotency_key: "future", next_attempt_at: 1.minute.from_now)

    assert_equal [ due_event ], OutboundEvent.due_for_dispatch.to_a
  end

  private

  def create_event(organization:, idempotency_key:, next_attempt_at:)
    OutboundEvent.create!(
      organization: organization,
      aggregate_type: "Ticket",
      aggregate_id: 1,
      event_type: "ticket.created",
      status: "pending",
      payload: { ticket_id: "TCK-000001" },
      idempotency_key: idempotency_key,
      correlation_id: idempotency_key,
      next_attempt_at: next_attempt_at
    )
  end
end
