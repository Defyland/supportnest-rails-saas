require "openssl"

module Security
  class TokenAuthenticator
    class << self
      def call!(authorization_header)
        token = bearer_token(authorization_header)
        membership = Membership.authenticate(token)

        raise AuthenticationError, "A valid bearer API token is required." unless membership&.active?

        membership.touch_last_seen!
        membership
      end

      def bearer_token(authorization_header)
        authorization_header.to_s.split(" ", 2).last if authorization_header.to_s.start_with?("Bearer ")
      end

      def digest(raw_token)
        OpenSSL::Digest::SHA256.hexdigest(raw_token.to_s)
      end
    end
  end
end
