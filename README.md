# SupportNest

SupportNest is a multi-tenant helpdesk SaaS API for B2B teams that need strict tenant isolation, role-based access control, auditable support workflows, and a clear path from a self-contained local demo to a production-grade support platform.

## 1. What is this product?

SupportNest models the operational core of a modern support desk:

- tenant bootstrap
- agent memberships with RBAC
- ticket creation and lifecycle updates
- audit logging for sensitive actions
- async outbound event dispatch for downstream integrations

This repository implements a vertical slice of that platform as a Rails 8 API.

## 2. Problem it solves

Many support tools are easy to demo but weak on multi-tenancy boundaries, operational evidence, and failure handling. SupportNest focuses on the engineering concerns that matter in SaaS support systems:

- cross-tenant data leaks must be prevented by default
- support agents need scoped permissions
- every sensitive action should be auditable
- asynchronous integrations should not block the API path
- platform health must be observable from logs, metrics, and traces

## 3. Target users

- B2B SaaS companies running internal support desks
- operations teams that need auditable ticket handling
- engineering leads evaluating tenant isolation and API platform maturity
- recruiters or interviewers assessing senior Rails backend execution

## 4. Main features

- `POST /v1/organizations` bootstraps a tenant and returns the initial owner token
- `GET /v1/organization` returns current tenant context for the authenticated membership
- `POST /v1/memberships` provisions tenant-scoped members and API tokens
- `PATCH /v1/memberships/:id` updates role or suspension state
- `POST /v1/tickets` creates tickets with quota enforcement and priority-based response deadlines
- `PATCH /v1/tickets/:id` updates status, inbox, priority, and assignee
- audit log records are created for bootstrap, membership, and ticket mutations
- outbound events are persisted and dispatched asynchronously via Active Job or the dedicated outbox relay
- `/up`, `/ready`, and `/metrics` expose platform health and telemetry surfaces

## 5. Architecture overview

SupportNest is implemented as a modular monolith with explicit application services:

- controllers handle transport concerns, authentication, authorization, and standardized errors
- services implement bootstrap, membership management, ticket workflows, audit logging, and event publication
- Active Record models carry validations, relationships, and local invariants
- an outbox-style `outbound_events` table plus relay decouples write paths from async delivery
- middleware attaches request context and collects Prometheus-style HTTP metrics

See [docs/architecture/overview.md](docs/architecture/overview.md), [docs/diagrams/container.md](docs/diagrams/container.md), and [docs/adr/005-modular-monolith-before-microservices.md](docs/adr/005-modular-monolith-before-microservices.md).

## 6. Tech stack

- Ruby `3.3.6`
- Rails `8.1`
- PostgreSQL as the primary development, test, benchmark, and CI database
- SQLite fallback through `DATABASE_ADAPTER=sqlite3` for a minimal local-only path
- Puma
- Active Job with the async adapter
- OpenTelemetry SDK and Rails instrumentation
- JSON structured logging
- Prometheus-style plaintext metrics endpoint backed by bounded counters and histograms
- prod-like Compose stack with app, outbox relay, PostgreSQL, OTLP collector, Prometheus, and Grafana
- Minitest with integration, model, and job coverage
- multi-stage Docker image running as a non-root `rails` user plus Docker Compose
- k6 benchmark scripts committed under `benchmarks/`

## 7. Domain model

| Entity | Purpose | Key constraints |
| --- | --- | --- |
| `Organization` | Tenant boundary and plan state | unique `slug`, seat and ticket quotas |
| `Membership` | Authenticated actor inside a tenant | unique `[organization_id, email]`, unique token digest |
| `Ticket` | Support request lifecycle | unique `[organization_id, public_id]`, optimistic lock column |
| `AuditLog` | Immutable action evidence | polymorphic auditable reference |
| `OutboundEvent` | Async integration buffer | unique `idempotency_key`, retry/backoff state, dead-letter metadata, replay lineage |

## 8. API documentation

- OpenAPI contract: [`openapi.yaml`](openapi.yaml)
- HTTP examples: [docs/api/http-examples.md](docs/api/http-examples.md)
- Error format: [docs/api/error-format.md](docs/api/error-format.md)

Authentication uses `Authorization: Bearer <membership_api_token>`.

## 9. Async or event architecture

Write-path mutations publish domain events through an outbox flow:

1. the mutation is committed in the primary transaction
2. an `OutboundEvent` record is stored with correlation metadata
3. in Active Job mode, `OutboundEventDispatchJob` is enqueued after commit
4. in relay mode, `bin/outbox relay --loop` claims due rows with PostgreSQL `FOR UPDATE SKIP LOCKED`
5. the dispatcher marks the event as `processing`, then `dispatched`, or schedules retry with exponential backoff
6. events that exceed the retry budget are marked `failed` with dead-letter metadata
7. operators can inspect `bin/outbox dlq` and replay through `bin/outbox replay <event_id>`

Current event types:

- `organization.bootstrapped`
- `membership.created`
- `membership.updated`
- `membership.token_revoked`
- `membership.token_rotated`
- `ticket.created`
- `ticket.updated`

Webhook delivery includes HMAC signature headers, idempotency keys, and explicit network timeouts. This keeps the request path fast while making integrations observable, retry-friendly, and operationally replayable.

## 10. Database design

- tenant-owned tables reference `organization_id`
- `memberships.api_token_digest` is stored instead of raw token material
- membership API tokens expire, can be rotated, and can be revoked
- `tickets.public_id` is tenant-scoped and exposed externally instead of numeric ids
- `tickets.lock_version` is exposed through `ETag`/`If-Match` for optimistic locking
- uniqueness and foreign-key constraints backstop application-level validations
- ticket identifiers are allocated from a tenant sequence inside the ticket creation transaction
- PostgreSQL row locking serializes tenant ticket sequence, ticket quota, and inbox quota updates under concurrent writers

See [docs/architecture/data-consistency.md](docs/architecture/data-consistency.md).

## 11. Testing strategy

The suite covers:

- model tests for normalization, validations, and cross-tenant constraints
- request/integration tests for bootstrap, memberships, tickets, and isolation
- authorization tests for forbidden viewer actions
- database constraint tests for unique indexes
- PostgreSQL concurrency tests for tenant ticket sequence allocation and quota exhaustion
- outbox relay concurrency tests for `FOR UPDATE SKIP LOCKED`, dead-letter, replay, and HMAC webhook signing
- job tests for outbound dispatch success and failure modes
- failure scenario coverage for unsupported event dispatch and rate limiting
- OpenAPI response contract tests for representative API flows

Run with `bin/rails test`.

## 12. Performance benchmarks

- benchmark scripts: [`benchmarks/`](benchmarks/)
- benchmark runner: `bin/benchmark smoke|load|stress|spike`
- methodology: [docs/benchmarks/methodology.md](docs/benchmarks/methodology.md)
- baseline definition: [benchmarks/baseline.md](benchmarks/baseline.md)
- captured results: [docs/benchmarks/local-baseline.md](docs/benchmarks/local-baseline.md)

The runner prepares an isolated `benchmark` database, starts Puma, waits for `/ready`, runs k6, captures CPU/RSS samples, and writes summaries under `benchmarks/results/`.

## 13. Observability

- JSON structured logs via `JsonLogFormatter`
- request-scoped `request_id` and `correlation_id`
- OpenTelemetry instrumentation with optional OTLP export through `OTEL_EXPORTER_OTLP_ENDPOINT`
- `/up` liveness probe
- `/ready` readiness probe with database check
- `/metrics` plaintext Prometheus endpoint backed by bounded in-process aggregation
- prod-like Prometheus alerts and Grafana provisioning under `ops/`
- Grafana dashboard definition: [docs/diagrams/grafana-supportnest-overview.json](docs/diagrams/grafana-supportnest-overview.json)

## 14. Security considerations

- membership-scoped bearer API tokens stored as SHA-256 digests
- token expiration, rotation, and revocation for membership API tokens
- config-backed RBAC matrix for `owner`, `admin`, `agent`, and `viewer`
- owner-continuity safeguards prevent non-owner actors from managing owner credentials and keep at least one reachable owner per tenant
- tenant isolation enforced in tenant-scoped lookups such as `current_organization.tickets.find_by!(public_id: ...)`
- PostgreSQL-backed per-token or per-IP rate limiting with hashed identifiers
- sensitive parameters filtered from logs
- audit logs on bootstrap, membership changes, and ticket lifecycle changes
- secrets supplied through environment variables at runtime rather than baked into the Docker image
- Docker runtime uses a multi-stage build and runs the Rails process as a non-root user

Security references:

- threat model: [docs/security/threat-model.md](docs/security/threat-model.md)
- authorization matrix: [docs/security/authorization-matrix.md](docs/security/authorization-matrix.md)
- outbound events: [docs/events/README.md](docs/events/README.md)
- authorization source of truth: `config/authorization_matrix.yml`

| Role | Org read | Membership list | Membership create/update | Ticket read | Ticket create/update |
| --- | --- | --- | --- | --- | --- |
| Owner | Yes | Yes | Yes | Yes | Yes |
| Admin | Yes | Yes | Yes | Yes | Yes |
| Agent | Yes | Yes | No | Yes | Yes |
| Viewer | Yes | Yes | No | Yes | No |

## 15. Trade-offs and decisions

- PostgreSQL is the primary runtime database; SQLite remains only as an explicit local fallback via `DATABASE_ADAPTER=sqlite3`.
- Active Job remains available for simple local dispatch; production mode defaults to the dedicated outbox relay unless `OUTBOX_DISPATCH_MODE=active_job` is explicitly set.
- Membership tokens avoid a full user identity system in this slice and keep the RBAC story focused on tenant boundaries.
- Metrics are exposed in Prometheus format without a dedicated client gem, but storage is bounded to counters, sums, and histogram buckets rather than per-request samples.
- Container scanning is exposed through `bin/container-scan` and expects Trivy in the operator environment.
- The Docker image does not bake `SECRET_KEY_BASE`; production-like Compose injects runtime env vars and real deployments should use a secrets manager.
- Webhook delivery fails closed when `OUTBOUND_WEBHOOK_URL` is configured without `OUTBOUND_WEBHOOK_SECRET`.

See the ADRs in [docs/adr/](docs/adr/).

## 16. How to run locally

```bash
bundle install
bin/rails db:prepare
bin/rails server
```

The default setup expects PostgreSQL on `127.0.0.1:5432` with user `postgres`. Override with `POSTGRES_HOST`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, and database-specific `POSTGRES_*_DB` variables, or use Docker Compose to start the app and database together.

Seed demo data:

```bash
bin/rails db:seed
```

Default local URL: `http://localhost:3000`

Production-like local stack:

```bash
docker compose -f docker-compose.prod-like.yml up --build
```

## 17. How to run tests

```bash
bin/rails test
bin/rubocop
bin/ci
bundle exec brakeman --quiet --no-pager --exit-on-warn --exit-on-error
bundle exec bundler-audit check --update
npx @redocly/cli@latest lint openapi.yaml
docker compose -f docker-compose.prod-like.yml config
docker build -t supportnest-ci .
bin/sbom --output tmp/sbom-gems.cdx.json
```

## 18. Failure scenarios

- seat limit exceeded when creating memberships returns `422`
- monthly ticket quota exceeded returns `422`
- missing or invalid bearer token returns `401`
- forbidden role action returns `403`
- cross-tenant ticket lookup returns `404`
- unsupported outbound event dispatch marks the event as `failed`
- exhausted outbound delivery moves the event to dead letter with replay lineage
- readiness returns `503` if the database probe fails

Operational guidance is documented in [docs/runbooks/common-issues.md](docs/runbooks/common-issues.md).
Production-readiness evidence is summarized in [docs/production-readiness.md](docs/production-readiness.md).

## 19. Roadmap

- add an external broker adapter for the outbox relay when signed webhook delivery is not sufficient
- add inbox SLAs, assignment rules, and webhook subscriptions
- add billing entities, seat enforcement by subscription, and invoice visibility roles
- expose audit log and outbound event APIs
- add managed alert routing and production dashboards beyond the local baseline
