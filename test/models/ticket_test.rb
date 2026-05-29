require "test_helper"

class TicketTest < ActiveSupport::TestCase
  test "assigns defaults when a ticket is created through the transactional flow" do
    organization = Organization.create!(name: "Acme", slug: unique_slug("acme"))
    raw_token, digest = Tokens::Issuer.issue(prefix: "sn_test_")
    owner = organization.memberships.create!(
      email: "owner@acme.test",
      full_name: "Owner",
      role: "owner",
      state: "active",
      api_token_digest: digest,
      api_token_last_eight: raw_token.last(8)
    )

    ticket = Tickets::Create.call!(
      organization: organization,
      actor: owner,
      attributes: {
        subject: "Customer cannot log in",
        description: "The login flow loops back to the sign-in page.",
        requester_name: "Jamie Customer",
        requester_email: "jamie@example.com",
        priority: "high"
      }
    )

    assert_equal "TCK-000001", ticket.public_id
    assert_equal "open", ticket.status
    assert ticket.resolution_due_at.present?
    assert_equal 2, organization.reload.next_ticket_sequence
  end

  test "requires assignee and creator to belong to the same organization" do
    organization = Organization.create!(name: "Acme", slug: unique_slug("acme"))
    another_organization = Organization.create!(name: "Other", slug: unique_slug("other"))

    raw_token, digest = Tokens::Issuer.issue(prefix: "sn_test_")
    owner = organization.memberships.create!(
      email: "owner@acme.test",
      full_name: "Owner",
      role: "owner",
      state: "active",
      api_token_digest: digest,
      api_token_last_eight: raw_token.last(8)
    )
    outsider = another_organization.memberships.create!(
      email: "outsider@other.test",
      full_name: "Other Agent",
      role: "agent",
      state: "active",
      api_token_digest: "digest-outsider",
      api_token_last_eight: "12345678"
    )

    ticket = organization.tickets.new(
      subject: "Cross-tenant assignment",
      description: "Should fail",
      requester_name: "Jamie Customer",
      requester_email: "jamie@example.com",
      created_by_membership: owner,
      assignee_membership: outsider
    )

    assert_not ticket.valid?
    assert_includes ticket.errors[:assignee_membership], "must belong to the same organization"
  end
end
