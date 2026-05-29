# Run using bin/ci

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Style: Ruby", "bin/rubocop"

  step "Security: Gem audit", "bundle exec bundler-audit check --update"
  step "Security: SBOM", "bin/sbom --output tmp/sbom-gems.cdx.json"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
  step "Contract: OpenAPI", "npx @redocly/cli@latest lint openapi.yaml"
  step "Ops: Production-like Compose", "docker compose -f docker-compose.prod-like.yml config >/tmp/supportnest-compose.yml"
  step "Container: Docker build", "docker build -t supportnest-ci ."
  step "Tests: Rails", "env RAILS_ENV=test bin/rails db:drop db:create db:migrate test"
  step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant"

  # Optional: Run system tests
  # step "Tests: System", "bin/rails test:system"

  # Optional: set a green GitHub commit status to unblock PR merge.
  # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`.
  # if success?
  #   step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  # else
  #   failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  # end
end
