require "test_helper"

class MutationTransactionBoundariesTest < ActiveSupport::TestCase
  test "membership update rolls back when event publication fails" do
    organization = Organization.create!(name: "Acme", slug: unique_slug("acme"))
    actor = create_membership(organization: organization, email: "owner@acme.test", role: "owner")
    membership = create_membership(organization: organization, email: "agent@acme.test", role: "agent")

    assert_no_difference [
      -> { AuditLog.where(action: "membership.updated").count },
      -> { OutboundEvent.where(event_type: "membership.updated").count }
    ] do
      assert_raises RuntimeError do
        with_failing_event_publisher do
          Memberships::Update.call!(
            membership: membership,
            actor: actor,
            attributes: { role: "admin" }
          )
        end
      end
    end

    assert_equal "agent", membership.reload.role
  end

  test "membership update does not emit audit or outbox records for no-op changes" do
    organization = Organization.create!(name: "Acme", slug: unique_slug("acme"))
    actor = create_membership(organization: organization, email: "owner@acme.test", role: "owner")
    membership = create_membership(organization: organization, email: "agent@acme.test", role: "agent")

    assert_no_difference [
      -> { AuditLog.where(action: "membership.updated").count },
      -> { OutboundEvent.where(event_type: "membership.updated").count }
    ] do
      Memberships::Update.call!(
        membership: membership,
        actor: actor,
        attributes: { role: "agent" }
      )
    end
  end

  test "membership token rotation rolls back when event publication fails" do
    organization = Organization.create!(name: "Acme", slug: unique_slug("acme"))
    actor = create_membership(organization: organization, email: "owner@acme.test", role: "owner")
    membership = create_membership(organization: organization, email: "agent@acme.test", role: "agent")
    original_digest = membership.api_token_digest
    original_last_eight = membership.api_token_last_eight
    original_expires_at = membership.api_token_expires_at

    assert_no_difference [
      -> { AuditLog.where(action: "membership.token_rotated").count },
      -> { OutboundEvent.where(event_type: "membership.token_rotated").count }
    ] do
      assert_raises RuntimeError do
        with_failing_event_publisher do
          Memberships::RotateToken.call!(membership: membership, actor: actor)
        end
      end
    end

    membership.reload
    assert_equal original_digest, membership.api_token_digest
    assert_equal original_last_eight, membership.api_token_last_eight
    assert_equal original_expires_at.to_i, membership.api_token_expires_at.to_i
    assert_nil membership.api_token_revoked_at
  end

  test "membership token revocation rolls back when event publication fails" do
    organization = Organization.create!(name: "Acme", slug: unique_slug("acme"))
    actor = create_membership(organization: organization, email: "owner@acme.test", role: "owner")
    membership = create_membership(organization: organization, email: "agent@acme.test", role: "agent")

    assert_no_difference [
      -> { AuditLog.where(action: "membership.token_revoked").count },
      -> { OutboundEvent.where(event_type: "membership.token_revoked").count }
    ] do
      assert_raises RuntimeError do
        with_failing_event_publisher do
          Memberships::RevokeToken.call!(membership: membership, actor: actor)
        end
      end
    end

    assert_not membership.reload.api_token_revoked?
  end

  test "ticket update rolls back when event publication fails" do
    organization = Organization.create!(name: "Acme", slug: unique_slug("acme"))
    actor = create_membership(organization: organization, email: "owner@acme.test", role: "owner")
    ticket = Tickets::Create.call!(
      organization: organization,
      actor: actor,
      attributes: {
        subject: "Customer cannot log in",
        description: "The login flow loops back to the sign-in page.",
        requester_name: "Jamie Customer",
        requester_email: "jamie@example.com"
      }
    )

    assert_no_difference [
      -> { AuditLog.where(action: "ticket.updated").count },
      -> { OutboundEvent.where(event_type: "ticket.updated").count }
    ] do
      assert_raises RuntimeError do
        with_failing_event_publisher do
          Tickets::Update.call!(
            ticket: ticket,
            actor: actor,
            attributes: { status: "pending" }
          )
        end
      end
    end

    ticket.reload
    assert_equal "open", ticket.status
    assert_nil ticket.first_response_at
  end

  test "ticket update does not emit audit or outbox records for no-op changes" do
    organization = Organization.create!(name: "Acme", slug: unique_slug("acme"))
    actor = create_membership(organization: organization, email: "owner@acme.test", role: "owner")
    ticket = Tickets::Create.call!(
      organization: organization,
      actor: actor,
      attributes: {
        subject: "Customer cannot log in",
        description: "The login flow loops back to the sign-in page.",
        requester_name: "Jamie Customer",
        requester_email: "jamie@example.com"
      }
    )

    assert_no_difference [
      -> { AuditLog.where(action: "ticket.updated").count },
      -> { OutboundEvent.where(event_type: "ticket.updated").count }
    ] do
      Tickets::Update.call!(
        ticket: ticket,
        actor: actor,
        attributes: { status: "open" }
      )
    end
  end

  private

  def create_membership(organization:, email:, role:)
    raw_token, digest = Tokens::Issuer.issue(prefix: "sn_test_")

    organization.memberships.create!(
      email: email,
      full_name: email.split("@").first.titleize,
      role: role,
      state: "active",
      api_token_digest: digest,
      api_token_last_eight: raw_token.last(8)
    )
  end

  def with_failing_event_publisher
    original_publish = Events::Publisher.method(:publish!)
    Events::Publisher.define_singleton_method(:publish!) { |**| raise "outbox unavailable" }

    yield
  ensure
    Events::Publisher.define_singleton_method(:publish!, original_publish)
  end
end
