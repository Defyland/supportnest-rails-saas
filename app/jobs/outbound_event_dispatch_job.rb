class OutboundEventDispatchJob < ApplicationJob
  UnsupportedEventType = OutboundEvents::Dispatcher::UnsupportedEventType

  queue_as :default
  MAX_ATTEMPTS = OutboundEvents::Dispatcher::MAX_ATTEMPTS
  BASE_RETRY_DELAY = OutboundEvents::Dispatcher::BASE_RETRY_DELAY
  SUPPORTED_EVENT_TYPES = OutboundEvents::Dispatcher::SUPPORTED_EVENT_TYPES

  def perform(outbound_event_id)
    event = OutboundEvent.find(outbound_event_id)
    OutboundEvents::Dispatcher.new(delivery: self.class, worker_id: "active_job").dispatch!(event)
  end

  def self.deliver(event)
    OutboundEvents::WebhookDelivery.new.deliver(event)
  end
end
