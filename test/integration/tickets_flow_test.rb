require "test_helper"

class TicketsFlowTest < ActionDispatch::IntegrationTest
  test "owner creates a member and agent creates a ticket within the tenant" do
    bootstrap = bootstrap_organization(slug: unique_slug("acme-helpdesk"))
    owner_token = bootstrap.dig("owner", "api_token")

    assert_difference -> { OutboundEvent.where(event_type: "membership.created").count }, +1 do
      post "/v1/memberships", params: {
        membership: {
          email: "agent@acme.test",
          full_name: "Agent Smith",
          role: "agent"
        }
      }, headers: auth_headers(owner_token), as: :json
    end

    assert_response :created
    agent_token = json_response.dig("membership", "api_token")

    assert_difference [
      -> { AuditLog.where(action: "ticket.created").count },
      -> { OutboundEvent.where(event_type: "ticket.created").count }
    ], +1 do
      post "/v1/tickets", params: {
        ticket: {
          subject: "Billing portal shows 500",
          description: "Customer sees a 500 on checkout confirmation.",
          requester_name: "Jamie Customer",
          requester_email: "jamie@example.com",
          inbox: "billing",
          priority: "urgent"
        }
      }, headers: auth_headers(agent_token), as: :json
    end

    assert_response :created
    assert_equal "TCK-000001", json_response.dig("ticket", "id")
    assert_equal "urgent", json_response.dig("ticket", "priority")
    assert_equal 0, json_response.dig("ticket", "lock_version")
    assert_equal "\"0\"", response.headers["ETag"]

    get "/v1/tickets/TCK-000001", headers: auth_headers(agent_token)

    assert_response :ok
    assert_equal "Billing portal shows 500", json_response.dig("ticket", "subject")
    assert_equal "\"0\"", response.headers["ETag"]
  end

  test "updates a ticket only when If-Match matches the current lock version" do
    bootstrap = bootstrap_organization(slug: unique_slug("locking-helpdesk"))
    owner_token = bootstrap.dig("owner", "api_token")

    post "/v1/tickets", params: {
      ticket: {
        subject: "Billing portal shows 500",
        description: "Customer sees a 500 on checkout confirmation.",
        requester_name: "Jamie Customer",
        requester_email: "jamie@example.com",
        inbox: "billing",
        priority: "urgent"
      }
    }, headers: auth_headers(owner_token), as: :json

    assert_response :created

    patch "/v1/tickets/TCK-000001", params: {
      ticket: { status: "pending" }
    }, headers: auth_headers(owner_token).merge("If-Match" => response.headers["ETag"]), as: :json

    assert_response :ok
    assert_equal "pending", json_response.dig("ticket", "status")
    assert_equal 1, json_response.dig("ticket", "lock_version")
    assert_equal "\"1\"", response.headers["ETag"]
  end

  test "rejects ticket updates with missing or stale If-Match headers" do
    bootstrap = bootstrap_organization(slug: unique_slug("stale-helpdesk"))
    owner_token = bootstrap.dig("owner", "api_token")

    post "/v1/tickets", params: {
      ticket: {
        subject: "Billing portal shows 500",
        description: "Customer sees a 500 on checkout confirmation.",
        requester_name: "Jamie Customer",
        requester_email: "jamie@example.com",
        inbox: "billing",
        priority: "urgent"
      }
    }, headers: auth_headers(owner_token), as: :json

    assert_response :created

    patch "/v1/tickets/TCK-000001", params: {
      ticket: { status: "pending" }
    }, headers: auth_headers(owner_token), as: :json

    assert_response :precondition_required
    assert_equal "precondition_required", json_response.dig("error", "code")

    patch "/v1/tickets/TCK-000001", params: {
      ticket: { status: "pending" }
    }, headers: auth_headers(owner_token).merge("If-Match" => "\"99\""), as: :json

    assert_response :conflict
    assert_equal "conflict", json_response.dig("error", "code")
  end

  test "rejects ticket update to a new inbox beyond the tenant inbox limit" do
    bootstrap = bootstrap_organization(
      slug: unique_slug("update-inbox-limit"),
      organization_attributes: { inbox_limit: 1 }
    )
    owner_token = bootstrap.dig("owner", "api_token")

    post "/v1/tickets", params: {
      ticket: {
        subject: "First ticket",
        description: "Uses the general inbox.",
        requester_name: "Jamie Customer",
        requester_email: "jamie@example.com",
        inbox: "general"
      }
    }, headers: auth_headers(owner_token), as: :json

    assert_response :created

    post "/v1/tickets", params: {
      ticket: {
        subject: "Second ticket",
        description: "Also uses the general inbox.",
        requester_name: "Alex Customer",
        requester_email: "alex@example.com",
        inbox: "general"
      }
    }, headers: auth_headers(owner_token), as: :json

    assert_response :created
    second_ticket_etag = response.headers["ETag"]

    patch "/v1/tickets/TCK-000002", params: {
      ticket: { inbox: "billing" }
    }, headers: auth_headers(owner_token).merge("If-Match" => second_ticket_etag), as: :json

    assert_response :unprocessable_entity
    assert_equal "validation_failed", json_response.dig("error", "code")
    assert_includes json_response.dig("error", "message"), "Inbox limit has been reached"
  end

  test "lists tickets with bounded pagination metadata" do
    bootstrap = bootstrap_organization(slug: unique_slug("paginated-tickets"))
    owner_token = bootstrap.dig("owner", "api_token")

    3.times do |index|
      post "/v1/tickets", params: {
        ticket: {
          subject: "Paginated ticket #{index}",
          description: "Ticket used to prove bounded collection responses.",
          requester_name: "Jamie Customer",
          requester_email: "customer-#{index}@example.com"
        }
      }, headers: auth_headers(owner_token), as: :json

      assert_response :created
    end

    get "/v1/tickets", params: { page: 1, limit: 2 }, headers: auth_headers(owner_token)

    assert_response :ok
    assert_equal 2, json_response.fetch("tickets").length
    assert_equal(
      {
        "page" => 1,
        "limit" => 2,
        "total_count" => 3,
        "total_pages" => 2,
        "next_page" => 2,
        "prev_page" => nil
      },
      json_response.fetch("pagination")
    )
  end

  test "rejects invalid ticket list query parameters instead of silently defaulting" do
    bootstrap = bootstrap_organization(slug: unique_slug("invalid-ticket-query"))
    owner_token = bootstrap.dig("owner", "api_token")

    get "/v1/tickets", params: { status: "archived" }, headers: auth_headers(owner_token)

    assert_response :bad_request
    assert_equal "invalid_parameter", json_response.dig("error", "code")
    assert_equal [ "must be one of: open, pending, resolved, closed" ], json_response.dig("error", "details", "status")

    get "/v1/tickets", params: { limit: 101 }, headers: auth_headers(owner_token)

    assert_response :bad_request
    assert_equal "invalid_parameter", json_response.dig("error", "code")
    assert_equal [ "must be between 1 and 100" ], json_response.dig("error", "details", "limit")

    get "/v1/tickets", params: { inbox: "billing queue!" }, headers: auth_headers(owner_token)

    assert_response :bad_request
    assert_equal "invalid_parameter", json_response.dig("error", "code")
    assert_equal [ "must be a URL-safe key" ], json_response.dig("error", "details", "inbox")
  end
end
