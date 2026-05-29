require "test_helper"

class RateLimitingAndMetricsTest < ActionDispatch::IntegrationTest
  test "returns 429 when the per-minute request limit is exceeded" do
    previous_value = ENV["RATE_LIMIT_REQUESTS_PER_MINUTE"]
    ENV["RATE_LIMIT_REQUESTS_PER_MINUTE"] = "1"

    begin
      post "/v1/organizations", params: {
        organization: { name: "Acme", slug: unique_slug("acme") },
        owner: { email: "owner@acme.test", full_name: "Owner" }
      }, as: :json

      assert_response :created

      post "/v1/organizations", params: {
        organization: { name: "Beta", slug: unique_slug("beta") },
        owner: { email: "owner@beta.test", full_name: "Owner" }
      }, as: :json

      assert_response :too_many_requests
      assert_equal "rate_limited", json_response.dig("error", "code")
    ensure
      ENV["RATE_LIMIT_REQUESTS_PER_MINUTE"] = previous_value
    end
  end

  test "exposes prometheus-style metrics" do
    get "/up"
    get "/metrics"

    assert_response :ok
    assert_includes response.body, "supportnest_http_requests_total"
    assert_includes response.body, "supportnest_http_request_duration_seconds"
  end
end
