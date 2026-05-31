require "test_helper"

class SecurityRateLimiterTest < ActiveSupport::TestCase
  setup do
    @previous_limit = ENV["RATE_LIMIT_REQUESTS_PER_MINUTE"]
    @previous_retention = ENV["RATE_LIMIT_RETENTION_SECONDS"]
    ENV["RATE_LIMIT_REQUESTS_PER_MINUTE"] = "2"
    ENV["RATE_LIMIT_RETENTION_SECONDS"] = "120"
    RateLimitBucket.delete_all
  end

  teardown do
    ENV["RATE_LIMIT_REQUESTS_PER_MINUTE"] = @previous_limit
    ENV["RATE_LIMIT_RETENTION_SECONDS"] = @previous_retention
    RateLimitBucket.delete_all
  end

  test "persists request counters in a database bucket keyed by digest" do
    identifier = "ip:203.0.113.10"

    assert_difference -> { RateLimitBucket.count }, +1 do
      Security::RateLimiter.check!(identifier)
    end

    bucket = RateLimitBucket.first
    assert_equal Security::RateLimiter.digest_identifier(identifier), bucket.identifier_digest
    assert_equal 1, bucket.requests_count
    refute_equal identifier, bucket.identifier_digest

    assert_no_difference -> { RateLimitBucket.count } do
      Security::RateLimiter.check!(identifier)
    end

    assert_equal 2, bucket.reload.requests_count
  end

  test "raises with retry metadata after the persisted window limit is exceeded" do
    identifier = "ip:198.51.100.7"

    2.times { Security::RateLimiter.check!(identifier) }

    error = assert_raises(Security::RateLimitExceeded) do
      Security::RateLimiter.check!(identifier)
    end

    assert_operator error.retry_after, :>, 0
    assert_equal 3, RateLimitBucket.first.requests_count
  end

  test "deletes expired buckets during rate limit checks" do
    RateLimitBucket.create!(
      identifier_digest: "expired",
      window_started_at: 10.minutes.ago,
      expires_at: 5.minutes.ago,
      requests_count: 1
    )

    assert_difference -> { RateLimitBucket.count }, 0 do
      Security::RateLimiter.check!("ip:192.0.2.44")
    end

    assert_nil RateLimitBucket.find_by(identifier_digest: "expired")
  end
end
