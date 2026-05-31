require "test_helper"

class RateLimitingAndMetricsTest < ActionDispatch::IntegrationTest
  setup do
    RateLimitBucket.delete_all if defined?(RateLimitBucket)
  end

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
      assert_equal 1, RateLimitBucket.count
      assert_equal 2, RateLimitBucket.first.requests_count
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

  test "metrics aggregate histograms without retaining per-request samples" do
    500.times do
      Observability::MetricsRegistry.record(
        method: "GET",
        path: "/v1/tickets/TCK-000001",
        status: 200,
        duration: 0.075
      )
    end

    rendered = Observability::MetricsRegistry.render

    refute Observability::MetricsRegistry.instance_variable_defined?(:@http_durations)
    assert_includes rendered, 'supportnest_http_request_duration_seconds_count{method="GET",path="/v1/tickets/:id",status="200"} 500'
    assert_includes rendered, 'supportnest_http_request_duration_seconds_bucket{method="GET",path="/v1/tickets/:id",status="200",le="0.1"} 500'
  end

  test "metrics collapse unknown paths to a bounded label" do
    10.times do |index|
      Observability::MetricsRegistry.record(
        method: "GET",
        path: "/unexpected/#{index}/#{SecureRandom.hex(4)}",
        status: 404,
        duration: 0.01
      )
    end

    rendered = Observability::MetricsRegistry.render

    assert_includes rendered, 'supportnest_http_requests_total{method="GET",path="/unmatched",status="404"} 10'
    refute_includes rendered, "/unexpected/"
  end
end
