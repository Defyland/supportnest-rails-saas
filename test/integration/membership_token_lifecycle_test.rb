require "test_helper"

class MembershipTokenLifecycleTest < ActionDispatch::IntegrationTest
  test "owner rotates a membership token and the previous token stops authenticating" do
    bootstrap = bootstrap_organization(slug: unique_slug("token-rotation"))
    owner_token = bootstrap.dig("owner", "api_token")

    post "/v1/memberships", params: {
      membership: {
        email: "agent@tenant.test",
        full_name: "Agent Smith",
        role: "agent"
      }
    }, headers: auth_headers(owner_token), as: :json

    assert_response :created
    membership_id = json_response.dig("membership", "id")
    previous_token = json_response.dig("membership", "api_token")

    assert_difference [
      -> { AuditLog.where(action: "membership.token_rotated").count },
      -> { OutboundEvent.where(event_type: "membership.token_rotated").count }
    ], +1 do
      patch "/v1/memberships/#{membership_id}/rotate_token", headers: auth_headers(owner_token), as: :json
    end

    assert_response :ok
    rotated_token = json_response.dig("membership", "api_token")
    assert rotated_token.start_with?("sn_member_")
    assert_not_equal previous_token, rotated_token
    assert json_response.dig("membership", "api_token_expires_at").present?

    get "/v1/organization", headers: auth_headers(previous_token)
    assert_response :unauthorized

    get "/v1/organization", headers: auth_headers(rotated_token)
    assert_response :ok
  end

  test "owner revokes a membership token" do
    bootstrap = bootstrap_organization(slug: unique_slug("token-revocation"))
    owner_token = bootstrap.dig("owner", "api_token")

    post "/v1/memberships", params: {
      membership: {
        email: "agent@tenant.test",
        full_name: "Agent Smith",
        role: "agent"
      }
    }, headers: auth_headers(owner_token), as: :json

    assert_response :created
    membership_id = json_response.dig("membership", "id")
    agent_token = json_response.dig("membership", "api_token")

    assert_difference [
      -> { AuditLog.where(action: "membership.token_revoked").count },
      -> { OutboundEvent.where(event_type: "membership.token_revoked").count }
    ], +1 do
      patch "/v1/memberships/#{membership_id}/revoke_token", headers: auth_headers(owner_token), as: :json
    end

    assert_response :ok
    assert json_response.dig("membership", "api_token_revoked_at").present?

    get "/v1/organization", headers: auth_headers(agent_token)

    assert_response :unauthorized
  end

  test "viewer cannot rotate membership tokens" do
    bootstrap = bootstrap_organization(slug: unique_slug("token-forbidden"))
    owner_token = bootstrap.dig("owner", "api_token")

    post "/v1/memberships", params: {
      membership: {
        email: "viewer@tenant.test",
        full_name: "Read Only",
        role: "viewer"
      }
    }, headers: auth_headers(owner_token), as: :json

    assert_response :created
    viewer_id = json_response.dig("membership", "id")
    viewer_token = json_response.dig("membership", "api_token")

    patch "/v1/memberships/#{viewer_id}/rotate_token", headers: auth_headers(viewer_token), as: :json

    assert_response :forbidden
    assert_equal "forbidden", json_response.dig("error", "code")
  end

  test "admin cannot mutate owner membership" do
    bootstrap = bootstrap_organization(slug: unique_slug("owner-guard-admin"))
    owner_id = bootstrap.dig("owner", "id")
    owner_token = bootstrap.dig("owner", "api_token")

    post "/v1/memberships", params: {
      membership: {
        email: "admin@tenant.test",
        full_name: "Admin User",
        role: "admin"
      }
    }, headers: auth_headers(owner_token), as: :json

    assert_response :created
    admin_token = json_response.dig("membership", "api_token")

    patch "/v1/memberships/#{owner_id}", params: {
      membership: { state: "suspended" }
    }, headers: auth_headers(admin_token), as: :json

    assert_response :forbidden
    assert_equal "forbidden", json_response.dig("error", "code")
    assert_equal "Only owners may manage owner memberships.", json_response.dig("error", "message")
  end

  test "last owner token cannot be revoked" do
    bootstrap = bootstrap_organization(slug: unique_slug("owner-guard-revoke"))
    owner_id = bootstrap.dig("owner", "id")
    owner_token = bootstrap.dig("owner", "api_token")

    patch "/v1/memberships/#{owner_id}/revoke_token", headers: auth_headers(owner_token), as: :json

    assert_response :forbidden
    assert_equal "forbidden", json_response.dig("error", "code")
    assert_equal "Organizations must keep at least one active owner with a valid token.",
                 json_response.dig("error", "message")
  end

  test "lists memberships with bounded pagination metadata" do
    bootstrap = bootstrap_organization(slug: unique_slug("paginated-memberships"))
    owner_token = bootstrap.dig("owner", "api_token")

    3.times do |index|
      post "/v1/memberships", params: {
        membership: {
          email: "agent-#{index}@tenant.test",
          full_name: "Agent #{index}",
          role: "agent"
        }
      }, headers: auth_headers(owner_token), as: :json

      assert_response :created
    end

    get "/v1/memberships", params: { page: 2, limit: 2 }, headers: auth_headers(owner_token)

    assert_response :ok
    assert_equal 2, json_response.fetch("memberships").length
    assert_equal 2, json_response.dig("pagination", "page")
    assert_equal 2, json_response.dig("pagination", "limit")
    assert_equal 4, json_response.dig("pagination", "total_count")
    assert_nil json_response.dig("pagination", "next_page")
    assert_equal 1, json_response.dig("pagination", "prev_page")
  end

  test "rejects invalid membership pagination parameters" do
    bootstrap = bootstrap_organization(slug: unique_slug("invalid-membership-query"))
    owner_token = bootstrap.dig("owner", "api_token")

    get "/v1/memberships", params: { page: "second" }, headers: auth_headers(owner_token)

    assert_response :bad_request
    assert_equal "invalid_parameter", json_response.dig("error", "code")
    assert_equal [ "must be an integer" ], json_response.dig("error", "details", "page")
  end
end
