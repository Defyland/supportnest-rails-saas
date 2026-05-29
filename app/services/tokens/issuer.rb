module Tokens
  class Issuer
    DEFAULT_TTL = 90.days

    def self.issue(prefix: "sn_live_")
      raw_token = "#{prefix}#{SecureRandom.base58(32)}"
      [ raw_token, Security::TokenAuthenticator.digest(raw_token) ]
    end

    def self.expires_at
      DEFAULT_TTL.from_now
    end
  end
end
