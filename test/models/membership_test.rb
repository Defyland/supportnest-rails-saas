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

  test "does not authenticate expired or revoked tokens" do
    organization = Organization.create!(name: "Acme", slug: unique_slug("acme"))
    raw_token, digest = Tokens::Issuer.issue(prefix: "sn_test_")
    membership = organization.memberships.create!(
      email: "owner@acme.test",
      full_name: "Owner",
      role: "owner",
      state: "active",
      api_token_digest: digest,
      api_token_last_eight: raw_token.last(8),
      api_token_expires_at: 1.hour.from_now
    )

    assert_equal membership, Membership.authenticate(raw_token)

    membership.update_columns(created_at: 2.hours.ago, api_token_expires_at: 1.hour.ago)
    assert_nil Membership.authenticate(raw_token)

    membership.update!(api_token_expires_at: 1.hour.from_now, api_token_revoked_at: Time.current)
    assert_nil Membership.authenticate(raw_token)
  end

  test "throttles last seen writes to avoid per-request write amplification" do
    organization = Organization.create!(name: "Acme", slug: unique_slug("last-seen"))
    raw_token, digest = Tokens::Issuer.issue(prefix: "sn_test_")
    membership = organization.memberships.create!(
      email: "owner@acme.test",
      full_name: "Owner",
      role: "owner",
      state: "active",
      api_token_digest: digest,
      api_token_last_eight: raw_token.last(8)
    )

    membership.touch_last_seen!
    first_seen_at = membership.reload.last_seen_at
    assert first_seen_at.present?

    membership.touch_last_seen!
    assert_equal first_seen_at.to_i, membership.reload.last_seen_at.to_i

    membership.update_columns(last_seen_at: 10.minutes.ago)
    membership.touch_last_seen!

    assert_operator membership.reload.last_seen_at, :>, 1.minute.ago
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
          api_token_expires_at: 90.days.from_now,
          created_at: Time.current,
          updated_at: Time.current
        }
      ])
    end
  end

  test "enforces membership role values at the database layer" do
    organization = Organization.create!(name: "Acme", slug: unique_slug("acme"))

    assert_raises(ActiveRecord::StatementInvalid) do
      Membership.insert_all!([
        {
          organization_id: organization.id,
          email: "invalid@acme.test",
          full_name: "Invalid",
          role: "superuser",
          state: "active",
          api_token_digest: "digest-invalid",
          api_token_last_eight: "12345678",
          api_token_expires_at: 90.days.from_now,
          created_at: Time.current,
          updated_at: Time.current
        }
      ])
    end
  end

  test "enforces token last-eight shape at the database layer" do
    organization = Organization.create!(name: "Acme", slug: unique_slug("acme"))

    assert_raises(ActiveRecord::StatementInvalid) do
      Membership.insert_all!([
        {
          organization_id: organization.id,
          email: "short-token@acme.test",
          full_name: "Short Token",
          role: "agent",
          state: "active",
          api_token_digest: "digest-short",
          api_token_last_eight: "short",
          api_token_expires_at: 90.days.from_now,
          created_at: Time.current,
          updated_at: Time.current
        }
      ])
    end
  end
end
