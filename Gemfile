source "https://rubygems.org"

ruby "3.3.6"

gem "rails", "~> 8.1.2"
gem "sqlite3", ">= 2.1"
gem "puma", ">= 5.0"
gem "tzinfo-data", platforms: %i[ windows jruby ]
gem "bootsnap", require: false
gem "opentelemetry-api"
gem "opentelemetry-exporter-otlp"
gem "opentelemetry-instrumentation-action_pack"
gem "opentelemetry-instrumentation-active_job"
gem "opentelemetry-instrumentation-active_record"
gem "opentelemetry-instrumentation-active_support"
gem "opentelemetry-instrumentation-rack"
gem "opentelemetry-sdk"

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "bundler-audit", require: false
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
  gem "simplecov", require: false
end
