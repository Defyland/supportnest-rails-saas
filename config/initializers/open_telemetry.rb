require "opentelemetry/sdk"
require "opentelemetry/exporter/otlp"

OpenTelemetry::SDK.configure do |config|
  config.service_name = "supportnest-api"

  if ENV["OTEL_EXPORTER_OTLP_ENDPOINT"].present?
    exporter = OpenTelemetry::Exporter::OTLP::Exporter.new(endpoint: ENV.fetch("OTEL_EXPORTER_OTLP_ENDPOINT"))
    processor = OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(exporter)
    config.add_span_processor(processor)
  end

  config.use "OpenTelemetry::Instrumentation::Rack"
  config.use "OpenTelemetry::Instrumentation::ActionPack"
  config.use "OpenTelemetry::Instrumentation::ActiveRecord"
  config.use "OpenTelemetry::Instrumentation::ActiveJob"
  config.use "OpenTelemetry::Instrumentation::ActiveSupport"
end
