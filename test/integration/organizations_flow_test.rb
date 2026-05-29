require "test_helper"

class OrganizationsFlowTest < ActionDispatch::IntegrationTest
  test "bootstraps an organization and returns current tenant context" do
    slug = unique_slug("acme-support")

    post "/v1/organizations", params: {
      organization: {
        name: "Acme Support",
        slug: slug,
        plan: "growth"
      },
      owner: {
        email: "owner@acme.test",
        full_name: "Owner Admin"
      }
    }, as: :json

    assert_response :created
    assert_equal slug, json_response.dig("organization", "slug")
    assert_equal "owner", json_response.dig("owner", "role")
    assert_equal 1, OutboundEvent.where(event_type: "organization.bootstrapped").count

    token = json_response.dig("owner", "api_token")

    get "/v1/organization", headers: auth_headers(token)

    assert_response :ok
    assert_equal "growth", json_response.dig("organization", "plan")
    assert_equal "owner@acme.test", json_response.dig("actor", "email")
  end
end
