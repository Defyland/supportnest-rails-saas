require "opentelemetry/sdk"

OpenTelemetry::SDK.configure do |config|
  config.service_name = "supportnest-api"
  config.use "OpenTelemetry::Instrumentation::Rack"
  config.use "OpenTelemetry::Instrumentation::ActionPack"
  config.use "OpenTelemetry::Instrumentation::ActiveRecord"
  config.use "OpenTelemetry::Instrumentation::ActiveJob"
  config.use "OpenTelemetry::Instrumentation::ActiveSupport"
end
