class PlatformController < ActionController::API
  after_action :set_observability_headers

  def live
    render json: { status: "ok", service: "supportnest-api", time: Time.current.iso8601 }
  end

  def ready
    ActiveRecord::Base.connection.execute("SELECT 1")

    render json: {
      status: "ready",
      checks: {
        database: "ok",
        jobs: Rails.application.config.active_job.queue_adapter.to_s
      }
    }
  rescue StandardError => error
    render json: {
      status: "degraded",
      error: error.message
    }, status: :service_unavailable
  end

  def metrics
    render plain: Observability::MetricsRegistry.render,
           content_type: "text/plain; version=0.0.4"
  end

  private

  def set_observability_headers
    response.set_header("X-Request-ID", Current.request_id || request.request_id)
    response.set_header("X-Correlation-ID", Current.correlation_id) if Current.correlation_id.present?
  end
end
