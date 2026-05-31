class ApplicationController < ActionController::API
  class InvalidParameter < StandardError
    attr_reader :details

    def initialize(message, details:)
      super(message)
      @details = details
    end
  end

  DEFAULT_PAGE_LIMIT = 50
  MAX_PAGE_LIMIT = 100

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

  rescue_from InvalidParameter do |error|
    render_error(
      code: "invalid_parameter",
      message: error.message,
      status: :bad_request,
      details: error.details
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

  rescue_from ActiveRecord::StaleObjectError do |_error|
    render_error(
      code: "conflict",
      message: "The resource was modified by another request.",
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

  def paginate(scope)
    page = query_integer_param!(:page, default: 1, minimum: 1)
    limit = query_integer_param!(:limit, default: DEFAULT_PAGE_LIMIT, minimum: 1, maximum: MAX_PAGE_LIMIT)
    total_count = scope.count
    total_pages = (total_count.to_f / limit).ceil
    total_pages = 1 if total_pages.zero?
    records = scope.limit(limit).offset((page - 1) * limit)

    [
      records,
      {
        page: page,
        limit: limit,
        total_count: total_count,
        total_pages: total_pages,
        next_page: page < total_pages ? page + 1 : nil,
        prev_page: page > 1 && page <= total_pages + 1 ? page - 1 : nil
      }
    ]
  end

  def query_integer_param!(name, default:, minimum:, maximum: nil)
    raw_value = params[name]
    return default if raw_value.blank?

    value = Integer(raw_value, 10)

    if value < minimum || (maximum.present? && value > maximum)
      bounds = maximum.present? ? "between #{minimum} and #{maximum}" : "greater than or equal to #{minimum}"
      raise InvalidParameter.new(
        "#{name} must be #{bounds}.",
        details: { name => [ "must be #{bounds}" ] }
      )
    end

    value
  rescue ArgumentError
    raise InvalidParameter.new(
      "#{name} must be an integer.",
      details: { name => [ "must be an integer" ] }
    )
  end

  def query_enum_param!(name, allowed_values)
    raw_value = params[name]
    return if raw_value.blank?
    return raw_value if allowed_values.include?(raw_value)

    raise InvalidParameter.new(
      "#{name} must be one of: #{allowed_values.join(', ')}.",
      details: { name => [ "must be one of: #{allowed_values.join(', ')}" ] }
    )
  end
end
