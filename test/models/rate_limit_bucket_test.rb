require "test_helper"

class RateLimitBucketTest < ActiveSupport::TestCase
  test "uses explicit indexes for stable schema review" do
    indexes = ActiveRecord::Base.connection.indexes(:rate_limit_buckets)
    window_index = indexes.find { |index| index.name == "index_rate_limit_buckets_on_identifier_window" }
    expiry_index = indexes.find { |index| index.name == "index_rate_limit_buckets_on_expires_at" }

    assert window_index, "expected stable rate limit bucket window index name"
    assert window_index.unique
    assert_equal %w[identifier_digest window_started_at], window_index.columns
    assert expiry_index, "expected rate limit bucket expiry cleanup index"
    assert_equal [ "expires_at" ], expiry_index.columns
  end
end
