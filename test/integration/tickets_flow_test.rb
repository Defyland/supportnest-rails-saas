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

    get "/v1/tickets/TCK-000001", headers: auth_headers(agent_token)

    assert_response :ok
    assert_equal "Billing portal shows 500", json_response.dig("ticket", "subject")
  end
end
