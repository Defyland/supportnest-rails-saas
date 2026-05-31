require "json"
require "net/http"
require "openssl"

module OutboundEvents
  class WebhookDelivery
    class ConfigurationError < StandardError; end

    SIGNATURE_HEADER = "X-SupportNest-Signature"
    TIMESTAMP_HEADER = "X-SupportNest-Signature-Timestamp"
    DEFAULT_TIMEOUT_SECONDS = 5

    def initialize(endpoint: ENV["OUTBOUND_WEBHOOK_URL"], secret: ENV["OUTBOUND_WEBHOOK_SECRET"],
                   timeout: ENV.fetch("OUTBOUND_WEBHOOK_TIMEOUT_SECONDS", DEFAULT_TIMEOUT_SECONDS).to_f)
      @endpoint = endpoint
      @secret = secret
      @timeout = timeout

      validate_configuration!
    end

    def deliver(event)
      body = JSON.generate(event.delivery_payload)
      timestamp = Time.now.to_i.to_s
      headers = signed_headers(event: event, body: body, timestamp: timestamp)

      if @endpoint.blank?
        Rails.logger.info(message: "outbound_event_delivery_dry_run", event_id: event.id, event_type: event.event_type)
        return true
      end

      uri = URI(@endpoint)
      response = Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: @timeout,
        read_timeout: @timeout,
        write_timeout: @timeout
      ) do |http|
        http.post(uri.request_uri, body, headers)
      end

      return true if response.is_a?(Net::HTTPSuccess)

      raise "Webhook delivery failed with #{response.code}: #{response.body}"
    end

    def signed_headers(event:, body:, timestamp:)
      {
        "Content-Type" => "application/json",
        "Idempotency-Key" => event.idempotency_key,
        "X-SupportNest-Event-ID" => event.id.to_s,
        "X-SupportNest-Event-Type" => event.event_type,
        TIMESTAMP_HEADER => timestamp,
        SIGNATURE_HEADER => self.class.signature(secret: signing_secret, timestamp: timestamp, body: body)
      }
    end

    def self.signature(secret:, timestamp:, body:)
      OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{body}")
    end

    private

    def validate_configuration!
      return if @endpoint.blank? || @secret.present?

      raise ConfigurationError, "OUTBOUND_WEBHOOK_SECRET is required when OUTBOUND_WEBHOOK_URL is configured."
    end

    def signing_secret
      @secret.presence || "development-outbound-secret"
    end
  end
end
