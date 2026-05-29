module Middleware
  class Metrics
    def initialize(app)
      @app = app
    end

    def call(env)
      request = ActionDispatch::Request.new(env)
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      status, headers, response = @app.call(env)

      [ status, headers, response ]
    ensure
      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
      Observability::MetricsRegistry.record(
        method: request.request_method,
        path: request.path,
        status: status || 500,
        duration: duration
      )
    end
  end
end
