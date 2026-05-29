require "test_helper"

class TicketConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  teardown do
    OutboundEvent.delete_all
    AuditLog.delete_all
    Ticket.delete_all
    Membership.delete_all
    Organization.delete_all
  end

  test "allocates tenant ticket ids contiguously under concurrent creates" do
    skip_unless_postgresql!

    organization, owner = create_tenant(ticket_limit: 20)
    results = concurrently_create_tickets(organization_id: organization.id, actor_id: owner.id, count: 8)

    assert_empty results.fetch(:errors)
    assert_equal (1..8).map { |number| format("TCK-%06d", number) }, results.fetch(:ticket_ids).sort
    assert_equal 8, organization.tickets.count
    assert_equal 8, organization.reload.current_month_ticket_count
    assert_equal 9, organization.next_ticket_sequence
  end

  test "enforces ticket quota atomically under concurrent creates" do
    skip_unless_postgresql!

    organization, owner = create_tenant(ticket_limit: 3)
    results = concurrently_create_tickets(organization_id: organization.id, actor_id: owner.id, count: 8)

    assert_equal (1..3).map { |number| format("TCK-%06d", number) }, results.fetch(:ticket_ids).sort
    assert_equal 5, results.fetch(:errors).count
    assert results.fetch(:errors).all? { |error| error.is_a?(ActiveRecord::RecordInvalid) }
    assert_equal 3, organization.tickets.count
    assert_equal 3, organization.reload.current_month_ticket_count
    assert_equal 4, organization.next_ticket_sequence
  end

  private

  def concurrently_create_tickets(organization_id:, actor_id:, count:)
    release = Queue.new
    results = Queue.new

    threads = count.times.map do |index|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          release.pop

          Current.correlation_id = "ticket-concurrency-#{index}"
          ticket = Tickets::Create.call!(
            organization: Organization.find(organization_id),
            actor: Membership.find(actor_id),
            attributes: ticket_attributes(index)
          )

          results << [ :ticket_id, ticket.public_id ]
        rescue ActiveRecord::RecordInvalid => error
          results << [ :error, error ]
        ensure
          Current.reset
        end
      end
    end

    count.times { release << true }
    threads.each(&:join)

    drain_results(results)
  end

  def drain_results(results)
    drained = { ticket_ids: [], errors: [] }

    drained_item = results.pop(true)
    until drained_item.nil?
      type, value = drained_item
      drained.fetch(type == :ticket_id ? :ticket_ids : :errors) << value
      drained_item = results.pop(true)
    end
  rescue ThreadError
    drained
  end

  def create_tenant(ticket_limit:)
    organization = Organization.create!(
      name: "Concurrent Tenant",
      slug: unique_slug("concurrent"),
      ticket_limit: ticket_limit
    )
    raw_token, digest = Tokens::Issuer.issue(prefix: "sn_test_")
    owner = organization.memberships.create!(
      email: "owner-#{organization.slug}@tenant.test",
      full_name: "Owner",
      role: "owner",
      state: "active",
      api_token_digest: digest,
      api_token_last_eight: raw_token.last(8)
    )

    [ organization, owner ]
  end

  def ticket_attributes(index)
    {
      subject: "Concurrent ticket #{index}",
      description: "Exercises tenant sequence and quota locking.",
      requester_name: "Concurrent Customer",
      requester_email: "customer-#{index}@concurrency.test",
      priority: "normal"
    }
  end

  def skip_unless_postgresql!
    return if ActiveRecord::Base.connection.adapter_name == "PostgreSQL"

    skip "PostgreSQL row-level locking is required for this concurrency specification"
  end
end
