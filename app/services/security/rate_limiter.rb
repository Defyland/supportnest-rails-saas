require "openssl"

module Security
  class RateLimiter
    WINDOW_SECONDS = 60
    DEFAULT_RETENTION_SECONDS = 5.minutes.to_i

    class << self
      def check!(identifier)
        now = Time.current
        window_started_at = current_window_started_at(now)
        bucket = nil

        RateLimitBucket.expired(now).delete_all

        RateLimitBucket.transaction do
          bucket = RateLimitBucket.create_or_find_by!(
            identifier_digest: digest_identifier(identifier),
            window_started_at: window_started_at
          ) do |new_bucket|
            new_bucket.requests_count = 0
            new_bucket.expires_at = window_started_at + window_seconds + retention_seconds
          end

          bucket.with_lock do
            bucket.requests_count = [ bucket.requests_count + 1, limit + 1 ].min
            bucket.expires_at = window_started_at + window_seconds + retention_seconds
            bucket.save!
          end
        end

        return if bucket.requests_count <= limit

        raise RateLimitExceeded.new(retry_after: retry_after(now, window_started_at))
      end

      def limit
        ENV.fetch("RATE_LIMIT_REQUESTS_PER_MINUTE", 120).to_i
      end

      def digest_identifier(identifier)
        OpenSSL::Digest::SHA256.hexdigest(identifier.to_s)
      end

      def reset!
        RateLimitBucket.delete_all if ActiveRecord::Base.connection.data_source_exists?("rate_limit_buckets")
      end

      private

      def window_seconds
        ENV.fetch("RATE_LIMIT_WINDOW_SECONDS", WINDOW_SECONDS).to_i
      end

      def retention_seconds
        ENV.fetch("RATE_LIMIT_RETENTION_SECONDS", DEFAULT_RETENTION_SECONDS).to_i
      end

      def current_window_started_at(now)
        Time.zone.at((now.to_i / window_seconds) * window_seconds)
      end

      def retry_after(now, window_started_at)
        [ (window_started_at + window_seconds - now).ceil, 1 ].max
      end
    end
  end
end
