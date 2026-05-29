require "test_helper"

class AuthorizationAndIsolationTest < ActionDispatch::IntegrationTest
  test "viewer cannot create tickets" do
    bootstrap = bootstrap_organization(slug: unique_slug("viewer-tenant"))
    owner_token = bootstrap.dig("owner", "api_token")

    post "/v1/memberships", params: {
      membership: {
        email: "viewer@tenant.test",
        full_name: "Read Only",
        role: "viewer"
      }
    }, headers: auth_headers(owner_token), as: :json

    viewer_token = json_response.dig("membership", "api_token")

    post "/v1/tickets", params: {
      ticket: {
        subject: "Forbidden action",
        description: "Should not be allowed.",
        requester_name: "Jamie Customer",
        requester_email: "jamie@example.com"
      }
    }, headers: auth_headers(viewer_token), as: :json

    assert_response :forbidden
    assert_equal "forbidden", json_response.dig("error", "code")
  end

  test "tenant tokens cannot access tickets from another tenant" do
    first_tenant = bootstrap_organization(slug: unique_slug("tenant-one"))
    second_tenant = bootstrap_organization(slug: unique_slug("tenant-two"))

    first_token = first_tenant.dig("owner", "api_token")
    second_token = second_tenant.dig("owner", "api_token")

    post "/v1/tickets", params: {
      ticket: {
        subject: "Private ticket",
        description: "Tenant isolation must hide this.",
        requester_name: "Jamie Customer",
        requester_email: "jamie@example.com"
      }
    }, headers: auth_headers(first_token), as: :json

    assert_response :created

    get "/v1/tickets/TCK-000001", headers: auth_headers(second_token)

    assert_response :not_found
    assert_equal "not_found", json_response.dig("error", "code")
  end
end
