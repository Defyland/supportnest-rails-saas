require "test_helper"

class EventsPublisherTest < ActiveSupport::TestCase
  test "enqueues Active Job dispatch by default" do
    organization = Organization.create!(name: "Acme", slug: unique_slug("publisher"))
    aggregate = organization

    assert_enqueued_with(job: OutboundEventDispatchJob) do
      Events::Publisher.publish!(
        organization: organization,
        aggregate: aggregate,
        event_type: "organization.bootstrapped",
        payload: { organization_id: organization.id }
      )
    end
  end

  test "does not enqueue Active Job dispatch when relay mode owns outbox delivery" do
    organization = Organization.create!(name: "Acme", slug: unique_slug("publisher-relay"))
    aggregate = organization

    with_outbox_dispatch_mode("relay") do
      assert_no_enqueued_jobs do
        Events::Publisher.publish!(
          organization: organization,
          aggregate: aggregate,
          event_type: "organization.bootstrapped",
          payload: { organization_id: organization.id }
        )
      end
    end
  end

  private

  def with_outbox_dispatch_mode(value)
    original_value = ENV["OUTBOX_DISPATCH_MODE"]
    ENV["OUTBOX_DISPATCH_MODE"] = value
    yield
  ensure
    ENV["OUTBOX_DISPATCH_MODE"] = original_value
  end
end
