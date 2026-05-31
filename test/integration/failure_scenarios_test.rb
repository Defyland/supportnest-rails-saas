require "test_helper"

class FailureScenariosTest < ActionDispatch::IntegrationTest
  test "returns 422 when the tenant seat limit is exhausted" do
    bootstrap = bootstrap_organization(
      slug: unique_slug("seat-limit"),
      organization_attributes: { seat_limit: 1 }
    )

    post "/v1/memberships", params: {
      membership: {
        email: "agent@tenant.test",
        full_name: "Agent Smith",
        role: "agent"
      }
    }, headers: auth_headers(bootstrap.dig("owner", "api_token")), as: :json

    assert_response :unprocessable_entity
    assert_equal "validation_failed", json_response.dig("error", "code")
    assert_includes json_response.dig("error", "message"), "Seat limit has been reached"
  end

  test "returns 422 when reactivating a membership would exceed the seat limit" do
    bootstrap = bootstrap_organization(
      slug: unique_slug("seat-reactivation"),
      organization_attributes: { seat_limit: 2 }
    )
    owner_token = bootstrap.dig("owner", "api_token")

    post "/v1/memberships", params: {
      membership: {
        email: "first-agent@tenant.test",
        full_name: "First Agent",
        role: "agent"
      }
    }, headers: auth_headers(owner_token), as: :json

    assert_response :created
    first_agent_id = json_response.dig("membership", "id")

    patch "/v1/memberships/#{first_agent_id}", params: {
      membership: { state: "suspended" }
    }, headers: auth_headers(owner_token), as: :json

    assert_response :ok

    post "/v1/memberships", params: {
      membership: {
        email: "second-agent@tenant.test",
        full_name: "Second Agent",
        role: "agent"
      }
    }, headers: auth_headers(owner_token), as: :json

    assert_response :created

    patch "/v1/memberships/#{first_agent_id}", params: {
      membership: { state: "active" }
    }, headers: auth_headers(owner_token), as: :json

    assert_response :unprocessable_entity
    assert_equal "validation_failed", json_response.dig("error", "code")
    assert_includes json_response.dig("error", "message"), "Seat limit has been reached"
  end

  test "returns 422 when the tenant ticket quota is exhausted" do
    bootstrap = bootstrap_organization(
      slug: unique_slug("ticket-limit"),
      organization_attributes: { ticket_limit: 1 }
    )
    owner_token = bootstrap.dig("owner", "api_token")

    post "/v1/tickets", params: {
      ticket: {
        subject: "First ticket",
        description: "Within the monthly quota.",
        requester_name: "Jamie Customer",
        requester_email: "jamie@example.com"
      }
    }, headers: auth_headers(owner_token), as: :json

    assert_response :created

    post "/v1/tickets", params: {
      ticket: {
        subject: "Second ticket",
        description: "Should exceed the quota.",
        requester_name: "Jamie Customer",
        requester_email: "jamie@example.com"
      }
    }, headers: auth_headers(owner_token), as: :json

    assert_response :unprocessable_entity
    assert_equal "validation_failed", json_response.dig("error", "code")
    assert_includes json_response.dig("error", "message"), "Ticket limit has been reached"
  end

  test "returns 422 when the tenant inbox limit is exhausted" do
    bootstrap = bootstrap_organization(
      slug: unique_slug("inbox-limit"),
      organization_attributes: { inbox_limit: 1 }
    )
    owner_token = bootstrap.dig("owner", "api_token")

    post "/v1/tickets", params: {
      ticket: {
        subject: "First inbox",
        description: "Uses the default general inbox.",
        requester_name: "Jamie Customer",
        requester_email: "jamie@example.com",
        inbox: "general"
      }
    }, headers: auth_headers(owner_token), as: :json

    assert_response :created

    post "/v1/tickets", params: {
      ticket: {
        subject: "Second inbox",
        description: "Should exceed the plan inbox quota.",
        requester_name: "Jamie Customer",
        requester_email: "jamie@example.com",
        inbox: "billing"
      }
    }, headers: auth_headers(owner_token), as: :json

    assert_response :unprocessable_entity
    assert_equal "validation_failed", json_response.dig("error", "code")
    assert_includes json_response.dig("error", "message"), "Inbox limit has been reached"
  end

  test "returns 422 for invalid ticket input" do
    bootstrap = bootstrap_organization(slug: unique_slug("invalid-ticket"))

    post "/v1/tickets", params: {
      ticket: {
        subject: "",
        description: "",
        requester_name: "Jamie Customer",
        requester_email: "not-an-email"
      }
    }, headers: auth_headers(bootstrap.dig("owner", "api_token")), as: :json

    assert_response :unprocessable_entity
    assert_equal "validation_failed", json_response.dig("error", "code")
    assert_includes json_response.dig("error", "details").keys, "subject"
    assert_includes json_response.dig("error", "details").keys, "description"
    assert_includes json_response.dig("error", "details").keys, "requester_email"
  end
end
