require "test_helper"

class MembershipOwnershipGuardTest < ActiveSupport::TestCase
  test "non-owner actors cannot manage owner memberships" do
    organization = create_organization
    owner = create_membership(organization: organization, role: "owner", email: "owner@example.test")
    admin = create_membership(organization: organization, role: "admin", email: "admin@example.test")

    error = assert_raises(Security::AuthorizationError) do
      Memberships::Update.call!(membership: owner, actor: admin, attributes: { state: "suspended" })
    end

    assert_equal "Only owners may manage owner memberships.", error.message
    assert owner.reload.active?
  end

  test "last authenticatable owner cannot be demoted" do
    organization = create_organization
    owner = create_membership(organization: organization, role: "owner", email: "owner@example.test")

    error = assert_raises(Security::AuthorizationError) do
      Memberships::Update.call!(membership: owner, actor: owner, attributes: { role: "admin" })
    end

    assert_equal "Organizations must keep at least one active owner with a valid token.", error.message
    assert owner.reload.owner?
  end

  test "owner can demote another owner when one authenticatable owner remains" do
    organization = create_organization
    first_owner = create_membership(organization: organization, role: "owner", email: "first-owner@example.test")
    second_owner = create_membership(organization: organization, role: "owner", email: "second-owner@example.test")

    Memberships::Update.call!(membership: second_owner, actor: first_owner, attributes: { role: "admin" })

    assert second_owner.reload.admin?
    assert first_owner.reload.owner?
  end

  test "non-owner actors cannot rotate owner tokens" do
    organization = create_organization
    owner = create_membership(organization: organization, role: "owner", email: "owner@example.test")
    admin = create_membership(organization: organization, role: "admin", email: "admin@example.test")

    error = assert_raises(Security::AuthorizationError) do
      Memberships::RotateToken.call!(membership: owner, actor: admin)
    end

    assert_equal "Only owners may manage owner memberships.", error.message
  end

  test "last authenticatable owner token cannot be revoked" do
    organization = create_organization
    owner = create_membership(organization: organization, role: "owner", email: "owner@example.test")

    error = assert_raises(Security::AuthorizationError) do
      Memberships::RevokeToken.call!(membership: owner, actor: owner)
    end

    assert_equal "Organizations must keep at least one active owner with a valid token.", error.message
    assert_not owner.reload.api_token_revoked?
  end

  private

  def create_organization
    Organization.create!(name: "Acme", slug: unique_slug("ownership"))
  end

  def create_membership(organization:, role:, email:)
    raw_token, digest = Tokens::Issuer.issue(prefix: "sn_test_")

    organization.memberships.create!(
      email: email,
      full_name: email.split("@").first.titleize,
      role: role,
      state: "active",
      api_token_digest: digest,
      api_token_last_eight: raw_token.last(8),
      api_token_expires_at: 90.days.from_now
    )
  end
end
