module Tokens
  class Issuer
    def self.issue(prefix: "sn_live_")
      raw_token = "#{prefix}#{SecureRandom.base58(32)}"
      [ raw_token, Security::TokenAuthenticator.digest(raw_token) ]
    end
  end
end
