module Security
  class RateLimitExceeded < StandardError
    attr_reader :retry_after

    def initialize(retry_after:)
      @retry_after = retry_after
      super("Rate limit exceeded")
    end
  end
end
