module Observability
  class MetricsRegistry
    HTTP_BUCKETS = [ 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0 ].freeze

    @mutex = Mutex.new
    @http_totals = Hash.new(0)
    @http_durations = Hash.new { |hash, key| hash[key] = [] }
    @outbound_totals = Hash.new(0)

    class << self
      def record(method:, path:, status:, duration:)
        labels = [ method.to_s.upcase, normalize_path(path), status.to_i ]

        @mutex.synchronize do
          @http_totals[labels] += 1
          @http_durations[labels] << duration
        end
      end

      def record_outbound(event_type:, status:)
        @mutex.synchronize do
          @outbound_totals[[ event_type, status.to_s ]] += 1
        end
      end

      def render
        snapshot = nil

        @mutex.synchronize do
          snapshot = {
            http_totals: @http_totals.deep_dup,
            http_durations: @http_durations.deep_dup,
            outbound_totals: @outbound_totals.deep_dup
          }
        end

        build_http_metrics(snapshot[:http_totals], snapshot[:http_durations]) +
          build_outbound_metrics(snapshot[:outbound_totals])
      end

      def reset!
        @mutex.synchronize do
          @http_totals.clear
          @http_durations.clear
          @outbound_totals.clear
        end
      end

      private

      def build_http_metrics(http_totals, http_durations)
        lines = []
        lines << "# HELP supportnest_http_requests_total Total HTTP requests processed."
        lines << "# TYPE supportnest_http_requests_total counter"

        http_totals.sort.each do |(method, path, status), count|
          lines << %(supportnest_http_requests_total{method="#{method}",path="#{path}",status="#{status}"} #{count})
        end

        lines << "# HELP supportnest_http_request_duration_seconds HTTP request duration histogram."
        lines << "# TYPE supportnest_http_request_duration_seconds histogram"

        http_durations.sort.each do |(method, path, status), durations|
          HTTP_BUCKETS.each do |bucket|
            count = durations.count { |value| value <= bucket }
            lines << %(supportnest_http_request_duration_seconds_bucket{method="#{method}",path="#{path}",status="#{status}",le="#{bucket}"} #{count})
          end

          lines << %(supportnest_http_request_duration_seconds_bucket{method="#{method}",path="#{path}",status="#{status}",le="+Inf"} #{durations.count})
          lines << %(supportnest_http_request_duration_seconds_sum{method="#{method}",path="#{path}",status="#{status}"} #{durations.sum.round(6)})
          lines << %(supportnest_http_request_duration_seconds_count{method="#{method}",path="#{path}",status="#{status}"} #{durations.count})
        end

        lines.join("\n") + "\n"
      end

      def build_outbound_metrics(outbound_totals)
        lines = []
        lines << "# HELP supportnest_outbound_events_total Total outbound domain events."
        lines << "# TYPE supportnest_outbound_events_total counter"

        outbound_totals.sort.each do |(event_type, status), count|
          lines << %(supportnest_outbound_events_total{event_type="#{event_type}",status="#{status}"} #{count})
        end

        lines.join("\n") + "\n"
      end

      def normalize_path(path)
        path.to_s
            .gsub(%r{/memberships/\d+}, "/memberships/:id")
            .gsub(%r{/tickets/[^/]+}, "/tickets/:id")
      end
    end
  end
end
