require "test_helper"
require "json"
require "open3"
require "yaml"

class RepositorySpecComplianceTest < ActiveSupport::TestCase
  README_SECTION_HEADINGS = [
    "## 1. What is this product?",
    "## 2. Problem it solves",
    "## 3. Target users",
    "## 4. Main features",
    "## 5. Architecture overview",
    "## 6. Tech stack",
    "## 7. Domain model",
    "## 8. API documentation",
    "## 9. Async or event architecture",
    "## 10. Database design",
    "## 11. Testing strategy",
    "## 12. Performance benchmarks",
    "## 13. Observability",
    "## 14. Security considerations",
    "## 15. Trade-offs and decisions",
    "## 16. How to run locally",
    "## 17. How to run tests",
    "## 18. Failure scenarios",
    "## 19. Roadmap"
  ].freeze

  REQUIRED_DIRECTORIES = %w[
    docs/adr
    docs/architecture
    docs/benchmarks
    docs/api
    docs/diagrams
    docs/events
    docs/runbooks
    ops/alerts
    ops/grafana/provisioning/dashboards
    ops/grafana/provisioning/datasources
  ].freeze

  REQUIRED_TEST_FILES = %w[
    test/models/organization_test.rb
    test/models/membership_test.rb
    test/models/ticket_test.rb
    test/integration/organizations_flow_test.rb
    test/integration/tickets_flow_test.rb
    test/integration/authorization_and_isolation_test.rb
    test/integration/failure_scenarios_test.rb
    test/integration/membership_token_lifecycle_test.rb
    test/integration/openapi_response_contract_test.rb
    test/integration/experiments_flow_test.rb
    test/integration/rate_limiting_and_metrics_test.rb
    test/jobs/outbound_event_dispatch_job_test.rb
      test/models/outbound_event_test.rb
      test/models/rate_limit_bucket_test.rb
      test/services/events_publisher_test.rb
      test/services/membership_ownership_guard_test.rb
      test/services/security_rate_limiter_test.rb
      test/services/outbound_events_relay_test.rb
    test/services/outbound_events_webhook_delivery_test.rb
    test/services/experiments_assignment_test.rb
    test/services/tickets_auto_router_test.rb
    test/services/mutation_transaction_boundaries_test.rb
    test/services/security_authorizer_test.rb
    test/services/ticket_concurrency_test.rb
  ].freeze

  REQUIRED_CI_CHECKS = [
    "actions/checkout@v5",
    "actions/setup-node@v5",
    "bin/rubocop",
    "bundle exec bundler-audit check --update",
    "bin/sbom --output tmp/sbom-gems.cdx.json",
    "bundle exec brakeman --quiet --no-pager --exit-on-warn --exit-on-error",
    "bin/rails test",
    "npx @redocly/cli@latest lint openapi.yaml",
    "docker compose -f docker-compose.prod-like.yml config",
    "postgres:16",
    "docker build -t supportnest-ci .",
    "actions/upload-artifact@v7"
  ].freeze
  REQUIRED_LOCAL_CI_CHECKS = [
    "bin/rubocop",
    "bundle exec bundler-audit check --update",
    "bin/sbom --output tmp/sbom-gems.cdx.json",
    "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error",
    "npx @redocly/cli@latest lint openapi.yaml",
    "docker compose -f docker-compose.prod-like.yml config",
    "docker build -t supportnest-ci .",
    "bin/rails db:drop db:create db:migrate test"
  ].freeze

  REQUIRED_COMMIT_PATTERN = /\A(?:build|chore|ci|docs|feat|fix|ops|perf|refactor|revert|style|test)(?:\([^)]+\))?: .+\z/
  LEGACY_ALLOWED_COMMIT_SUBJECTS = [
    "Add MIT License For Publication"
  ].freeze
  REQUIRED_SCENARIOS = %w[smoke load stress spike].freeze

  test "keeps the mandatory documentation structure and entrypoint files" do
    REQUIRED_DIRECTORIES.each do |directory|
      assert_path_exists directory
      assert File.directory?(absolute_path(directory)), "#{directory} must remain a directory"
    end

    %w[
      README.md
      Dockerfile
      openapi.yaml
      config/ci.rb
      db/schema.sqlite.rb
      config/authorization_matrix.yml
      bin/outbox
      bin/sbom
      bin/container-scan
      docker-compose.prod-like.yml
      ops/prometheus.yml
      ops/otel-collector.yml
      ops/alerts/supportnest.yml
      ops/grafana/provisioning/dashboards/supportnest.yml
      ops/grafana/provisioning/datasources/prometheus.yml
      docs/production-readiness.md
      docs/api/http-examples.md
      docs/api/error-format.md
      docs/benchmarks/methodology.md
      docs/benchmarks/local-baseline.md
      docs/adr/003-postgresql-primary.md
      docs/adr/004-production-outbox-relay.md
      docs/adr/005-modular-monolith-before-microservices.md
      docs/adr/008-deterministic-experiments-for-ticket-routing.md
      docs/architecture/deployment-readiness.md
      docs/events/README.md
      docs/events/outbound_event.v1.json
      docs/runbooks/common-issues.md
      docs/runbooks/outbox-relay.md
      docs/runbooks/disaster-recovery.md
      docs/runbooks/event-contract-change.md
    ].each do |path|
      assert_path_exists path
    end
  end

  test "keeps the README sections required by the repository spec in order" do
    readme = read_file("README.md")
    previous_index = -1

    README_SECTION_HEADINGS.each do |heading|
      current_index = readme.index(heading)

      assert current_index, "README.md must include #{heading.inspect}"
      assert_operator(
        current_index,
        :>,
        previous_index,
        "#{heading.inspect} must remain after the previous required section"
      )

      previous_index = current_index
    end
  end

  test "keeps the HTTP API baseline artifacts and examples" do
    openapi = YAML.safe_load(read_file("openapi.yaml"), aliases: true)
    paths = openapi.fetch("paths")
    security_scheme = openapi.dig("components", "securitySchemes", "BearerAuth")
    responses = openapi.fetch("components").fetch("responses")
    http_examples = read_file("docs/api/http-examples.md")
    error_format = read_file("docs/api/error-format.md")

    assert_equal "3.1.0", openapi.fetch("openapi")
    assert_includes paths.keys, "/v1/organizations"
    assert_includes paths.keys, "/v1/organization"
    assert_includes paths.keys, "/v1/memberships"
    assert_includes paths.keys, "/v1/tickets"
    assert_includes paths.keys, "/v1/experiments/{experiment_key}/assignments"
    assert_includes paths.keys, "/v1/experiments/{experiment_key}/conversions"
    assert paths.keys.any? { |path| path.match?(%r{\A/v1/}) }, "OpenAPI paths must remain versioned"

    assert_equal "http", security_scheme.fetch("type")
    assert_equal "bearer", security_scheme.fetch("scheme")

    %w[Unauthorized Forbidden ValidationFailed RateLimited].each do |response_name|
      assert responses.key?(response_name), "OpenAPI components.responses must include #{response_name}"
    end

    assert_includes http_examples, "Authorization: Bearer"
    assert_includes http_examples, "## Validation failure example"
    assert_includes http_examples, "## Authorization failure example"
    assert_includes http_examples, "## Tenant-isolation failure example"
    assert_includes http_examples, "## Assign an experiment variant"
    assert_includes http_examples, "## Record an experiment conversion"

    %w[missing_parameter invalid_parameter unauthorized forbidden not_found conflict validation_failed rate_limited].each do |code|
      assert_includes error_format, code
    end
  end

  test "keeps the CI workflow checks required by the repository spec" do
    workflow = read_file(".github/workflows/ci.yml")

    REQUIRED_CI_CHECKS.each do |check|
      assert_includes workflow, check
    end
  end

  test "keeps the local CI runner aligned with the production readiness checks" do
    local_ci = read_file("config/ci.rb")

    REQUIRED_LOCAL_CI_CHECKS.each do |check|
      assert_includes local_ci, check
    end
  end

  test "keeps PostgreSQL as the primary verified database with explicit SQLite fallback" do
    database_config = read_file("config/database.yml")
    docker_compose = read_file("docker-compose.yml")
    adr = read_file("docs/adr/003-postgresql-primary.md")

    assert_includes database_config, "adapter: postgresql"
    assert_includes database_config, "DATABASE_ADAPTER"
    assert_includes database_config, "adapter: sqlite3"
    assert_includes database_config, "schema_dump: schema.sqlite.rb"
    assert_includes database_config, "supportnest_test"
    assert_includes docker_compose, "postgres:16"
    assert_includes adr, "PostgreSQL as the default database"
  end

  test "keeps security observability and data consistency artifacts required by the spec" do
    threat_model = read_file("docs/security/threat-model.md")
    authorization_matrix = read_file("docs/security/authorization-matrix.md")
    data_consistency = read_file("docs/architecture/data-consistency.md")
    grafana_dashboard = JSON.parse(read_file("docs/diagrams/grafana-supportnest-overview.json"))
    event_schema = JSON.parse(read_file("docs/events/outbound_event.v1.json"))
    event_docs = read_file("docs/events/README.md")
    modular_monolith_adr = read_file("docs/adr/005-modular-monolith-before-microservices.md")
    deployment_readiness = read_file("docs/architecture/deployment-readiness.md")
    event_contract_runbook = read_file("docs/runbooks/event-contract-change.md")
    production_readiness = read_file("docs/production-readiness.md")
    prod_like_compose = read_file("docker-compose.prod-like.yml")
    dockerfile = read_file("Dockerfile")
    production_config = read_file("config/environments/production.rb")
    prometheus_alerts = read_file("ops/alerts/supportnest.yml")

    [ "Scope", "Trust boundaries", "Primary threats", "Tests mapped to threats" ].each do |phrase|
      assert_includes threat_model, phrase
    end

    [ "BOLA", "RBAC", "API tokens", "Audit log", "Rate limiting", "Outbound events" ].each do |phrase|
      assert_includes threat_model, phrase
    end

    %w[owner admin agent viewer tickets_create tickets_update].each do |phrase|
      assert_includes authorization_matrix, phrase
    end

    %w[experiments_assign experiments_convert].each do |phrase|
      assert_includes authorization_matrix, phrase
    end

    [
      "Transaction boundaries",
      "Indexes and constraints",
      "Optimistic locking",
      "Experiment assignment and conversion",
      "Isolation assumptions",
      "Migration strategy",
      "Rollback strategy",
      "FOR UPDATE SKIP LOCKED",
      "dead-letter"
    ].each do |heading|
      assert_includes data_consistency, heading
    end

    %w[outbox-relay prometheus grafana otel-collector OUTBOX_DISPATCH_MODE].each do |term|
      assert_includes prod_like_compose, term
    end

    assert_includes prod_like_compose, "RAILS_ALLOWED_HOSTS"
    assert_includes production_config, "config.hosts.concat"
    assert_includes production_config, "RAILS_ALLOWED_HOSTS"

    assert_includes dockerfile, "USER rails:rails"
    assert_includes dockerfile, "RAILS_LOG_TO_STDOUT=1"
    assert_includes dockerfile, "AS build"
    assert_includes dockerfile, "BUNDLE_DEPLOYMENT=1"
    assert_includes dockerfile, "COPY --from=build"

    %w[SupportNestReadinessDown SupportNestHighServerErrorRate SupportNestOutboundDeadLetters].each do |alert|
      assert_includes prometheus_alerts, alert
    end

    %w[Outbox Operations Security Backups].each do |term|
      assert_includes production_readiness, term
    end

    %w[
      organization.bootstrapped
      membership.token_rotated
      ticket.updated
      FOR\ UPDATE\ SKIP\ LOCKED
      Idempotency-Key
      X-SupportNest-Signature
    ].each do |term|
      assert_includes event_docs, term
    end

    %w[
      organization.bootstrapped
      membership.token_revoked
      ticket.created
      ticket.updated
    ].each do |event_type|
      assert_includes event_schema.dig("properties", "event_type", "enum"), event_type
    end

    [
      "Modular Rails monolith",
      "Microservices per domain module",
      "Tenant isolation implications",
      "Future service extraction must preserve tenant context"
    ].each do |term|
      assert_includes modular_monolith_adr, term
    end

    assert_includes deployment_readiness, "Non-root container execution"
    assert_includes deployment_readiness, "Secret manager integration"
    assert_includes event_contract_runbook, "deduplicate by `X-SupportNest-Event-ID` or `Idempotency-Key`"

    assert grafana_dashboard.key?("panels"), "Grafana dashboard JSON must define panels"
    assert_operator(
      grafana_dashboard.fetch("panels").length,
      :>,
      0,
      "Grafana dashboard must contain at least one panel"
    )
  end

  test "keeps benchmark scenarios measured artifacts and required metrics evidence" do
    baseline = read_file("benchmarks/baseline.md")
    local_baseline = read_file("docs/benchmarks/local-baseline.md")

    assert_path_exists "benchmarks/baseline.md"
    assert_path_exists "benchmarks/lib/supportnest.js"
    assert_path_exists "benchmarks/results/README.md"
    assert_path_exists "bin/benchmark"

    %w[p50 p95 p99 Throughput Error rate].each do |metric_label|
      assert_includes local_baseline, metric_label
    end

    assert_includes local_baseline, "CPU"
    assert_includes local_baseline, "RSS"

    benchmark_runner = read_file("bin/benchmark")
    %w[
      BENCHMARK_RAILS_ENV
      db:drop
      db:create
      db:migrate
      wait_for_ready!
      server
      resource-samples
      RATE_LIMIT_REQUESTS_PER_MINUTE
    ].each do |term|
      assert_includes benchmark_runner, term
    end

    REQUIRED_SCENARIOS.each do |scenario|
      assert_includes baseline.downcase, scenario
      assert_includes local_baseline, scenario.capitalize
      assert_path_exists "benchmarks/#{scenario}.js"
      assert_path_exists "benchmarks/results/#{scenario}-summary.txt"
      assert_path_exists "benchmarks/results/#{scenario}-summary.json"
      assert_path_exists "benchmarks/results/#{scenario}-resource-samples.tsv"

      summary = JSON.parse(read_file("benchmarks/results/#{scenario}-summary.json"))
      metrics = summary.fetch("metrics")

      assert metrics.key?("http_req_duration"), "#{scenario} summary must expose http_req_duration"
      assert metrics.key?("http_req_failed"), "#{scenario} summary must expose http_req_failed"
      assert metrics.key?("http_reqs"), "#{scenario} summary must expose throughput data"
      assert metrics.fetch("http_req_duration").key?("p(95)")
      assert metrics.fetch("http_req_duration").key?("p(99)")
    end
  end

  test "keeps explicit test coverage for the critical repository layers" do
    REQUIRED_TEST_FILES.each do |path|
      assert_path_exists path
    end
  end

  test "uses conventional commits when git history is available" do
    skip "git metadata is not available in this environment" unless File.directory?(absolute_path(".git"))

    stdout, stderr, status = Open3.capture3("/usr/bin/git", "log", "--format=%s", "--no-merges")

    assert status.success?, "git log failed: #{stderr}"

    subjects = stdout.lines.map(&:strip).reject(&:empty?)

    assert subjects.any?, "git history must contain at least one commit subject"

    subjects.each do |subject|
      next if LEGACY_ALLOWED_COMMIT_SUBJECTS.include?(subject)

      assert_match(
        REQUIRED_COMMIT_PATTERN,
        subject,
        "Commit subject must follow Conventional Commits: #{subject.inspect}"
      )
    end
  end

  private

  def read_file(relative_path)
    File.read(absolute_path(relative_path))
  end

  def absolute_path(relative_path)
    Rails.root.join(relative_path)
  end

  def assert_path_exists(relative_path)
    assert File.exist?(absolute_path(relative_path)), "#{relative_path} must exist"
  end
end
