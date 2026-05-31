module Observability
  class MetricsRegistry
    HTTP_BUCKETS = [ 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0 ].freeze

    @mutex = Mutex.new
    @http_totals = Hash.new(0)
    @http_duration_buckets = Hash.new { |hash, key| hash[key] = Hash.new(0) }
    @http_duration_sums = Hash.new(0.0)
    @http_duration_counts = Hash.new(0)
    @outbound_totals = Hash.new(0)

    class << self
      def record(method:, path:, status:, duration:)
        labels = [ method.to_s.upcase, normalize_path(path), status.to_i ]

        @mutex.synchronize do
          @http_totals[labels] += 1
          HTTP_BUCKETS.each do |bucket|
            @http_duration_buckets[labels][bucket] += 1 if duration <= bucket
          end
          @http_duration_sums[labels] += duration
          @http_duration_counts[labels] += 1
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
            http_duration_buckets: @http_duration_buckets.deep_dup,
            http_duration_sums: @http_duration_sums.deep_dup,
            http_duration_counts: @http_duration_counts.deep_dup,
            outbound_totals: @outbound_totals.deep_dup
          }
        end

        build_http_metrics(
          snapshot[:http_totals],
          snapshot[:http_duration_buckets],
          snapshot[:http_duration_sums],
          snapshot[:http_duration_counts]
        ) +
          build_outbound_metrics(snapshot[:outbound_totals])
      end

      def reset!
        @mutex.synchronize do
          @http_totals.clear
          @http_duration_buckets.clear
          @http_duration_sums.clear
          @http_duration_counts.clear
          @outbound_totals.clear
        end
      end

      private

      def build_http_metrics(http_totals, http_duration_buckets, http_duration_sums, http_duration_counts)
        lines = []
        lines << "# HELP supportnest_http_requests_total Total HTTP requests processed."
        lines << "# TYPE supportnest_http_requests_total counter"

        http_totals.sort.each do |(method, path, status), count|
          lines << %(supportnest_http_requests_total{method="#{method}",path="#{path}",status="#{status}"} #{count})
        end

        lines << "# HELP supportnest_http_request_duration_seconds HTTP request duration histogram."
        lines << "# TYPE supportnest_http_request_duration_seconds histogram"

        http_duration_counts.sort.each do |(method, path, status), count|
          labels = [ method, path, status ]
          HTTP_BUCKETS.each do |bucket|
            bucket_count = http_duration_buckets.fetch(labels).fetch(bucket, 0)
            lines << %(supportnest_http_request_duration_seconds_bucket{method="#{method}",path="#{path}",status="#{status}",le="#{bucket}"} #{bucket_count})
          end

          lines << %(supportnest_http_request_duration_seconds_bucket{method="#{method}",path="#{path}",status="#{status}",le="+Inf"} #{count})
          lines << %(supportnest_http_request_duration_seconds_sum{method="#{method}",path="#{path}",status="#{status}"} #{http_duration_sums.fetch(labels).round(6)})
          lines << %(supportnest_http_request_duration_seconds_count{method="#{method}",path="#{path}",status="#{status}"} #{count})
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
        normalized_path = path.to_s

        case normalized_path
        when "/up", "/ready", "/metrics", "/v1/organizations", "/v1/organization", "/v1/memberships", "/v1/tickets"
          normalized_path
        when %r{\A/v1/memberships/\d+\z}
          "/v1/memberships/:id"
        when %r{\A/v1/memberships/\d+/(rotate_token|revoke_token)\z}
          "/v1/memberships/:id/#{Regexp.last_match(1)}"
        when %r{\A/v1/tickets/[^/]+\z}
          "/v1/tickets/:id"
        else
          "/unmatched"
        end
      end
    end
  end
end
