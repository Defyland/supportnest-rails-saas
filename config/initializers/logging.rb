class JsonLogFormatter < Logger::Formatter
  def call(severity, timestamp, progname, msg)
    payload = msg.is_a?(Hash) ? msg.dup : { message: msg.to_s }
    payload[:severity] = severity
    payload[:timestamp] = timestamp.utc.iso8601(3)
    payload[:progname] = progname if progname.present?
    payload[:request_id] ||= Current.request_id
    payload[:correlation_id] ||= Current.correlation_id

    "#{payload.compact.to_json}\n"
  end
end

logger = ActiveSupport::Logger.new($stdout)
logger.formatter = JsonLogFormatter.new
Rails.application.config.logger = ActiveSupport::TaggedLogging.new(logger)
