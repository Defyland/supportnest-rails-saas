require "test_helper"

class ExperimentsFlowTest < ActionDispatch::IntegrationTest
  test "agent assigns and records a conversion for an active experiment" do
    bootstrap = bootstrap_organization(slug: unique_slug("experiment-flow"))
    owner_token = bootstrap.dig("owner", "api_token")
    organization = Organization.find_by!(slug: bootstrap.dig("organization", "slug"))
    create_experiment(organization)

    post "/v1/experiments/ticket-routing/assignments", params: {
      assignment: {
        subject_key: "customer-123",
        context: { inbox: "billing", priority: "urgent" }
      }
    }, headers: auth_headers(owner_token), as: :json

    assert_response :created
    assert_equal "ticket-routing", json_response.dig("assignment", "experiment_key")
    assert_equal "customer-123", json_response.dig("assignment", "subject_key")
    assert_includes %w[least-open-tickets sla-priority], json_response.dig("assignment", "variant", "key")

    post "/v1/experiments/ticket-routing/conversions", params: {
      conversion: {
        subject_key: "customer-123",
        event_name: "ticket_resolved",
        idempotency_key: "ticket:TCK-000001:resolved",
        metadata: { ticket_id: "TCK-000001" }
      }
    }, headers: auth_headers(owner_token), as: :json

    assert_response :created
    assert_equal "ticket-routing", json_response.dig("conversion", "experiment_key")
    assert_equal "ticket_resolved", json_response.dig("conversion", "event_name")
    assert_equal "ticket:TCK-000001:resolved", json_response.dig("conversion", "idempotency_key")
  end

  test "viewer cannot mutate experiment assignment state" do
    bootstrap = bootstrap_organization(slug: unique_slug("experiment-viewer"))
    owner_token = bootstrap.dig("owner", "api_token")
    organization = Organization.find_by!(slug: bootstrap.dig("organization", "slug"))
    create_experiment(organization)

    post "/v1/memberships", params: {
      membership: {
        email: "viewer@experiment.test",
        full_name: "Read Only",
        role: "viewer"
      }
    }, headers: auth_headers(owner_token), as: :json

    viewer_token = json_response.dig("membership", "api_token")

    post "/v1/experiments/ticket-routing/assignments", params: {
      assignment: { subject_key: "customer-123" }
    }, headers: auth_headers(viewer_token), as: :json

    assert_response :forbidden
    assert_equal "forbidden", json_response.dig("error", "code")
  end

  private

  def create_experiment(organization)
    organization.experiments.create!(
      key: "ticket-routing",
      name: "Ticket routing",
      status: "active"
    ).tap do |experiment|
      experiment.experiment_variants.create!(key: "least-open-tickets", name: "Least open tickets", weight: 50)
      experiment.experiment_variants.create!(key: "sla-priority", name: "SLA priority", weight: 50)
    end
  end
end
