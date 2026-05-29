ENV["RAILS_ENV"] ||= "test"
require "simplecov"

SimpleCov.start("rails") do
  add_filter "/test/"
end

require_relative "../config/environment"
require "rails/test_help"
require "active_job/test_helper"

Dir[Rails.root.join("test/support/**/*.rb")].sort.each { |file| require file }

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)
    include ActiveJob::TestHelper

    setup do
      Security::RateLimiter.reset!
      Observability::MetricsRegistry.reset!
      clear_enqueued_jobs
      clear_performed_jobs
    end
  end
end

class ActionDispatch::IntegrationTest
  include ApiTestHelper
end

module TestRecordHelper
  def unique_slug(prefix = "tenant")
    "#{prefix}-#{SecureRandom.hex(4)}"
  end
end

module ActiveSupport
  class TestCase
    include TestRecordHelper
  end
end

class ActionDispatch::IntegrationTest
  include TestRecordHelper
end
