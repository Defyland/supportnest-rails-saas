require "test_helper"
require "json"

class OutboundEventsWebhookDeliveryTest < ActiveSupport::TestCase
  test "builds deterministic HMAC signature headers for outbound webhooks" do
    organization = Organization.create!(name: "Acme", slug: unique_slug("webhook"))
    event = OutboundEvent.create!(
      organization: organization,
      aggregate_type: "Ticket",
      aggregate_id: 1,
      event_type: "ticket.created",
      status: "pending",
      payload: { ticket_id: "TCK-000001" },
      idempotency_key: "webhook-event",
      correlation_id: "webhook-correlation"
    )
    delivery = OutboundEvents::WebhookDelivery.new(secret: "secret")
    body = JSON.generate(event.delivery_payload)

    headers = delivery.signed_headers(event: event, body: body, timestamp: "1234567890")

    assert_equal "application/json", headers.fetch("Content-Type")
    assert_equal event.idempotency_key, headers.fetch("Idempotency-Key")
    assert_equal event.event_type, headers.fetch("X-SupportNest-Event-Type")
    assert_equal "1234567890", headers.fetch(OutboundEvents::WebhookDelivery::TIMESTAMP_HEADER)
    assert_equal(
      OutboundEvents::WebhookDelivery.signature(secret: "secret", timestamp: "1234567890", body: body),
      headers.fetch(OutboundEvents::WebhookDelivery::SIGNATURE_HEADER)
    )
  end

  test "fails closed when a real webhook endpoint is configured without a secret" do
    error = assert_raises(OutboundEvents::WebhookDelivery::ConfigurationError) do
      OutboundEvents::WebhookDelivery.new(endpoint: "https://events.example.test/supportnest", secret: nil)
    end

    assert_match "OUTBOUND_WEBHOOK_SECRET", error.message
  end
end
