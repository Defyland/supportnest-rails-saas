require "test_helper"
require "yaml"

class OpenapiResponseContractTest < ActionDispatch::IntegrationTest
  test "bootstrap organization response satisfies the OpenAPI contract" do
    post "/v1/organizations", params: {
      organization: {
        name: "Acme Support",
        slug: unique_slug("contract-org"),
        plan: "growth"
      },
      owner: {
        email: "owner@contract.test",
        full_name: "Owner Admin"
      }
    }, as: :json

    assert_response :created
    assert_required_keys(json_response, "OrganizationBootstrapResponse")
  end

  test "ticket create and update responses satisfy the OpenAPI contract" do
    bootstrap = bootstrap_organization(slug: unique_slug("contract-ticket"))
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
    assert_required_keys(json_response.fetch("ticket"), "Ticket")
    etag = response.headers.fetch("ETag")

    patch "/v1/tickets/TCK-000001", params: {
      ticket: { status: "pending" }
    }, headers: auth_headers(owner_token).merge("If-Match" => etag), as: :json

    assert_response :ok
    assert_required_keys(json_response.fetch("ticket"), "Ticket")
  end

  test "experiment assignment and conversion responses satisfy the OpenAPI contract" do
    bootstrap = bootstrap_organization(slug: unique_slug("contract-experiment"))
    owner_token = bootstrap.dig("owner", "api_token")
    organization = Organization.find_by!(slug: bootstrap.dig("organization", "slug"))
    experiment = organization.experiments.create!(key: "ticket-routing", name: "Ticket routing", status: "active")
    experiment.experiment_variants.create!(key: "least-open-tickets", name: "Least open tickets", weight: 50)
    experiment.experiment_variants.create!(key: "sla-priority", name: "SLA priority", weight: 50)

    post "/v1/experiments/ticket-routing/assignments", params: {
      assignment: { subject_key: "customer-123" }
    }, headers: auth_headers(owner_token), as: :json

    assert_response :created
    assert_required_keys(json_response.fetch("assignment"), "ExperimentAssignment")

    post "/v1/experiments/ticket-routing/conversions", params: {
      conversion: {
        subject_key: "customer-123",
        event_name: "ticket_resolved",
        idempotency_key: "ticket:TCK-000001:resolved"
      }
    }, headers: auth_headers(owner_token), as: :json

    assert_response :created
    assert_required_keys(json_response.fetch("conversion"), "ExperimentConversion")
  end

  private

  def assert_required_keys(payload, schema_name)
    schema = openapi_schema(schema_name)
    schema.fetch("required", []).each do |key|
      assert payload.key?(key), "#{schema_name} response must include #{key.inspect}"
    end
  end

  def openapi_schema(schema_name)
    @openapi_schema ||= YAML.safe_load(Rails.root.join("openapi.yaml").read, aliases: true)
    @openapi_schema.fetch("components").fetch("schemas").fetch(schema_name)
  end
end
