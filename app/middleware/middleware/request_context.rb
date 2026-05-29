module Middleware
  class RequestContext
    def initialize(app)
      @app = app
    end

    def call(env)
      request = ActionDispatch::Request.new(env)

      Current.request_id = request.request_id
      Current.correlation_id = request.get_header("HTTP_X_CORRELATION_ID").presence || SecureRandom.uuid
      Current.remote_ip = request.remote_ip
      Current.user_agent = request.user_agent

      status, headers, response = @app.call(env)
      headers["X-Request-ID"] ||= Current.request_id if Current.request_id.present?
      headers["X-Correlation-ID"] = Current.correlation_id
      headers["X-Trace-ID"] = trace_id if trace_id

      [ status, headers, response ]
    ensure
      Current.reset
    end

    private

    def trace_id
      span = OpenTelemetry::Trace.current_span
      return if span.nil?

      context = span.context
      return if context.nil? || !context.valid?

      context.hex_trace_id
    end
  end
end
