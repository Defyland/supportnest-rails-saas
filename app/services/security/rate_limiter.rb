module Security
  class RateLimiter
    WINDOW_SECONDS = 60

    @mutex = Mutex.new
    @requests = Hash.new { |hash, key| hash[key] = [] }

    class << self
      def check!(identifier)
        now = Process.clock_gettime(Process::CLOCK_REALTIME)
        retry_after = nil

        @mutex.synchronize do
          bucket = @requests[identifier]
          bucket.reject! { |timestamp| timestamp <= now - WINDOW_SECONDS }

          if bucket.size >= limit
            retry_after = (WINDOW_SECONDS - (now - bucket.first)).ceil
          else
            bucket << now
          end
        end

        return unless retry_after

        raise RateLimitExceeded.new(retry_after: [ retry_after, 1 ].max)
      end

      def limit
        ENV.fetch("RATE_LIMIT_REQUESTS_PER_MINUTE", 120).to_i
      end

      def reset!
        @mutex.synchronize { @requests.clear }
      end
    end
  end
end
