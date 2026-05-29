class ApplicationController < ActionController::API
  before_action :enforce_rate_limit!
  before_action :authenticate_membership!
  after_action :set_observability_headers

  rescue_from ActionController::ParameterMissing do |error|
    render_error(
      code: "missing_parameter",
      message: error.message,
      status: :bad_request
    )
  end

  rescue_from ActiveRecord::RecordInvalid do |error|
    render_error(
      code: "validation_failed",
      message: error.record.errors.full_messages.to_sentence,
      status: :unprocessable_entity,
      details: error.record.errors.to_hash(true)
    )
  end

  rescue_from ActiveRecord::RecordNotUnique do |_error|
    render_error(
      code: "conflict",
      message: "The request conflicts with an existing record.",
      status: :conflict
    )
  end

  rescue_from ActiveRecord::RecordNotFound do |_error|
    render_error(
      code: "not_found",
      message: "The requested resource was not found.",
      status: :not_found
    )
  end

  rescue_from Security::AuthenticationError do |error|
    render_error(
      code: "unauthorized",
      message: error.message,
      status: :unauthorized
    )
  end

  rescue_from Security::AuthorizationError do |error|
    render_error(
      code: "forbidden",
      message: error.message,
      status: :forbidden
    )
  end

  rescue_from Security::RateLimitExceeded do |error|
    render_error(
      code: "rate_limited",
      message: "Rate limit exceeded. Retry later.",
      status: :too_many_requests,
      retry_after: error.retry_after
    )
  end

  private

  def authenticate_membership!
    membership = Security::TokenAuthenticator.call!(request.authorization)
    Current.membership = membership
    Current.organization = membership.organization
  end

  def current_membership
    Current.membership
  end

  def current_organization
    Current.organization
  end

  def authorize!(permission)
    Security::Authorizer.authorize!(current_membership, permission)
  end

  def render_error(code:, message:, status:, details: nil, retry_after: nil)
    response.set_header("Retry-After", retry_after.to_s) if retry_after.present?

    render json: {
      error: {
        code: code,
        message: message,
        details: details,
        request_id: Current.request_id || request.request_id,
        correlation_id: Current.correlation_id
      }.compact
    }, status: status
  end

  def enforce_rate_limit!
    Security::RateLimiter.check!(rate_limit_key)
  end

  def rate_limit_key
    token = Security::TokenAuthenticator.bearer_token(request.authorization)

    if token.present?
      "token:#{Security::TokenAuthenticator.digest(token)}"
    else
      "ip:#{request.remote_ip}"
    end
  end

  def set_observability_headers
    response.set_header("X-Request-ID", Current.request_id || request.request_id)
    response.set_header("X-Correlation-ID", Current.correlation_id) if Current.correlation_id.present?

    span = OpenTelemetry::Trace.current_span
    return if span.nil? || span.context.nil? || !span.context.valid?

    response.set_header("X-Trace-ID", span.context.hex_trace_id)
  end
end
