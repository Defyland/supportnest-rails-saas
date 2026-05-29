require "test_helper"

class MembershipTest < ActiveSupport::TestCase
  test "authenticates only active memberships by token" do
    organization = Organization.create!(name: "Acme", slug: unique_slug("acme"))
    raw_token, digest = Tokens::Issuer.issue(prefix: "sn_test_")
    membership = organization.memberships.create!(
      email: "OWNER@ACME.TEST",
      full_name: "Owner",
      role: "owner",
      state: "active",
      api_token_digest: digest,
      api_token_last_eight: raw_token.last(8)
    )

    assert_equal "owner@acme.test", membership.reload.email
    assert_equal membership, Membership.authenticate(raw_token)

    membership.update!(state: "suspended")

    assert_nil Membership.authenticate(raw_token)
  end

  test "enforces the unique membership email per organization in the database" do
    organization = Organization.create!(name: "Acme", slug: unique_slug("acme"))

    organization.memberships.create!(
      email: "owner@acme.test",
      full_name: "Owner",
      role: "owner",
      state: "active",
      api_token_digest: "digest-1",
      api_token_last_eight: "12345678"
    )

    assert_raises(ActiveRecord::RecordNotUnique) do
      Membership.insert_all!([
        {
          organization_id: organization.id,
          email: "owner@acme.test",
          full_name: "Duplicate",
          role: "agent",
          state: "active",
          api_token_digest: "digest-2",
          api_token_last_eight: "87654321",
          created_at: Time.current,
          updated_at: Time.current
        }
      ])
    end
  end
end
