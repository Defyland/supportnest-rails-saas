# Senior Technical Validation

This document evaluates the SupportNest implementation as evidence of senior backend engineering. The assessment is limited to the repository artifacts, tests, architecture decisions, and measured behavior currently present in this project.

## Verdict

The project demonstrates senior-level execution for a Rails API challenge. The strongest signals are the deliberate product narrative, explicit tenant-boundary modeling, config-backed RBAC, auditability, production-shaped outbox relay, bounded operational surfaces, operational documentation, benchmark evidence, and CI/security automation.

That said, seniority is not only about breadth of features. The project also needed tighter executable guardrails around the written spec and stricter alignment between documented transaction boundaries and service implementation. Those gaps were addressed in this validation pass.

## Senior-Level Signals

| Area | Evidence | Why it matters |
| --- | --- | --- |
| Product framing | `README.md` describes users, problem, domain model, failure modes, and roadmap | Shows the author can communicate a system as a product, not just code |
| Tenant isolation | Controllers scope lookups through the current organization and tests cover cross-tenant access | Reduces BOLA risk, a core SaaS backend concern |
| Authorization | `config/authorization_matrix.yml`, `Security::Authorizer`, and `docs/security/authorization-matrix.md` define role permissions | Makes access control explicit, reviewable, and testable against drift |
| PostgreSQL consistency | PostgreSQL is the default dev/test/benchmark/CI adapter and concurrency tests cover ticket sequence and quota races | Proves consistency behavior against production-like database semantics |
| Auditability | Mutating flows write audit logs for organization, membership, and ticket changes | Supports incident review and compliance-style evidence |
| Async design | `OutboundEvents::Relay` claims events with `FOR UPDATE SKIP LOCKED`, tracks dead letters, and supports replay lineage | Avoids coupling external integrations to the request path and shows operational failure handling |
| Observability | Structured logs, correlation IDs, health/readiness, bounded metrics, OTLP export, Prometheus alerts, and Grafana provisioning exist | Shows operational maturity beyond happy-path implementation |
| Performance evidence | k6 smoke/load/stress/spike results are committed with CPU/RSS notes and a reusable benchmark runner | Replaces performance claims with measured data |
| Security baseline | Threat model, token hashing, PostgreSQL-backed rate limiting, secret filtering, non-root multi-stage container runtime, and security scans are present | Demonstrates attention to practical abuse cases |
| Delivery hygiene | Conventional Commit history and CI checks are present | Makes the work reviewable and maintainable |

## Improvements Required or Worth Making

| Finding | Severity | Status | Technical reasoning |
| --- | --- | --- | --- |
| Spec compliance was mostly documented but not executable | Medium | Fixed | A senior implementation should turn important repository standards into regression tests where practical |
| Some integration tests asserted absolute global counts | Medium | Fixed | Tests became order-dependent after seeds or previous data; delta assertions are more robust |
| Membership and ticket update services did not wrap `save + audit + outbox` in one transaction | High | Fixed | The data-consistency doc promised transaction boundaries, but partial writes could occur if event publication failed |
| Current persistence uses SQLite | Medium | Fixed | PostgreSQL is now the primary adapter for development, test, benchmark, Docker Compose, and CI; SQLite is explicit fallback only |
| Outbox dispatch has local retry/backoff but no production relay | Medium | Fixed | A dedicated relay now uses PostgreSQL locking, dead-letter metadata, replay lineage, stale-processing recovery, and signed webhook delivery |
| OpenAPI validation was syntax-only | Medium | Fixed | Representative API responses are now checked against required fields from the OpenAPI contract |
| Benchmarks required too much manual orchestration | Medium | Fixed | `bin/benchmark` now prepares an isolated DB, starts Puma, waits for readiness, runs k6, captures CPU/RSS, and writes results |
| Production-readiness evidence was scattered | Low | Fixed | `docs/production-readiness.md`, prod-like Compose, Prometheus alerts, runbooks, SBOM generation, and optional container scan script document the remaining cloud-dependent controls |
| Membership tokens have expiry, rotation, and revocation | Medium | Fixed | Digest storage is now paired with token lifecycle controls and audit evidence |
| Optimistic locking is present and exposed via HTTP preconditions | Low | Fixed | Ticket updates now require `If-Match` and return `409 conflict` on stale versions |
| Authorization permissions lived only in Ruby | Low | Fixed | The RBAC matrix is now a versioned YAML source loaded by the authorizer and checked by tests |
| Rate limiting was process-local memory | High | Fixed | Request counters now live in PostgreSQL buckets keyed by hashed token/IP identifiers, with expiry and regression tests |
| Metrics retained per-request duration samples | High | Fixed | Metrics now store bounded counters, sums, and histogram buckets instead of unbounded request arrays |
| Collection endpoints could return unbounded tenant data | Medium | Fixed | Membership and ticket list endpoints now accept `page`/`limit` and return pagination metadata documented in OpenAPI |
| Production async dispatch could silently use process-local Active Job | High | Fixed | Production default now assigns dispatch ownership to the relay; Active Job dispatch is opt-in via `OUTBOX_DISPATCH_MODE=active_job` |
| Webhook signing secret had an unsafe configured-endpoint fallback | High | Fixed | Webhook delivery raises a configuration error when `OUTBOUND_WEBHOOK_URL` is present without `OUTBOUND_WEBHOOK_SECRET` |
| Docker image carried build tooling into runtime | Medium | Fixed | Dockerfile now uses a multi-stage build with bundle deployment and a non-root runtime layer |
| Authentication touched membership rows on every request | Medium | Fixed | `last_seen_at` writes are throttled to keep the signal while avoiding avoidable write amplification |
| Owner continuity depended on coarse RBAC only | High | Fixed | Membership owner update, token rotation, and token revocation now reject non-owner actors and preserve at least one active owner with a valid token under an organization lock |
| `inbox_limit` was modeled but not enforced | Medium | Fixed | Ticket create/update now normalize inbox keys, enforce tenant inbox quotas under the organization lock, and back the field with an index plus database length constraint |

## Changes Executed In This Validation

1. Added `RepositorySpecComplianceTest` to make the general project spec executable for repository structure, README sections, API artifacts, CI coverage, security docs, benchmark evidence, critical tests, and Conventional Commit history.
2. Replaced fragile absolute-count integration assertions with `assert_difference` checks around the mutation being exercised.
3. Wrapped `Memberships::Update` and `Tickets::Update` in database transactions so model update, audit log, and outbox event are committed or rolled back together.
4. Added transaction-boundary tests that force event publication failure and prove membership/ticket state and audit records roll back.
5. Added PostgreSQL as the primary adapter, PostgreSQL-backed concurrency tests, database check constraints, HTTP optimistic-lock preconditions, token lifecycle controls, outbox retry/backoff state, OpenAPI response contract tests, and a reusable benchmark runner.
6. Promoted authorization permissions to `config/authorization_matrix.yml` and added drift tests against the runtime authorizer and membership roles.
7. Added production outbox relay controls: `FOR UPDATE SKIP LOCKED`, dead-letter metadata, replay lineage, signed webhook delivery, relay CLI, and concurrency tests.
8. Added production-readiness artifacts: prod-like Compose, non-root Docker runtime, OTLP collector config, Prometheus alert rules, Grafana provisioning, SBOM generation, and operational runbooks.
9. Documented this technical validation to separate implemented fixes from remaining cloud-dependent controls.
10. Replaced process-local rate limiting with PostgreSQL-backed fixed-window buckets and executable regression coverage.
11. Reworked Prometheus metrics to keep bounded histogram/counter state instead of per-request samples.
12. Added bounded pagination contracts for membership and ticket collection endpoints.
13. Hardened production defaults for outbox ownership, webhook secret handling, and Docker runtime composition.
14. Throttled `last_seen_at` refreshes so authentication does not write the membership row on every request.
15. Added membership ownership guards so admins cannot mutate owner credentials and tenants cannot lose the last reachable owner.
16. Enforced tenant inbox quotas during ticket creation/update and added schema/test coverage for inbox keys.

## Spec-Driven Evidence

| Spec area | Repository evidence |
| --- | --- |
| Documentation structure | `test/repository_spec_compliance_test.rb` checks mandatory docs directories and core files |
| README standard | `test/repository_spec_compliance_test.rb` checks the required README sections in order |
| API baseline | `openapi.yaml`, `docs/api/http-examples.md`, and `docs/api/error-format.md` are checked by the compliance test |
| Testing baseline | Model, integration, authorization, failure, messaging, performance, and transaction tests are present |
| CI baseline | `.github/workflows/ci.yml` and `config/ci.rb` cover lint, tests, security, SBOM, OpenAPI, prod-like Compose, Docker build, and coverage artifact upload |
| Observability baseline | Bounded metrics, tracing, health/readiness endpoints, OTLP collector config, Prometheus alerts, and Grafana dashboard provisioning are present |
| Performance baseline | k6 scenarios, an automated benchmark runner, and measured results are committed under `benchmarks/` and `docs/benchmarks/` |
| Security baseline | Threat model, config-backed authorization matrix, token lifecycle, PostgreSQL-backed rate limiting, validation, tenant isolation, and audit logging are documented and tested |
| Data and transaction baseline | `docs/architecture/data-consistency.md`, PostgreSQL config, relay locking, and transaction/concurrency tests cover the consistency-sensitive flows |
| Production readiness baseline | `docs/production-readiness.md`, prod-like Compose, non-root multi-stage Docker runtime, outbox and DR runbooks, SBOM generation, and optional container scan script are present |
| Commit history standard | Conventional Commit history is checked when git metadata is available |

## Final Assessment

The author shows senior-level capability in system framing, operational discipline, security awareness, and backend architecture. The main technical correction needed was to make implicit promises executable: spec compliance moved into tests, fragile assertions were stabilized, documented transaction boundaries now match the services, access-control policy now has a single tested source of truth, and local-only operational shortcuts were replaced by bounded or database-backed controls.

The project is strong as a senior challenge submission and now includes a production-readiness slice. The remaining gap to real production is cloud attachment: managed secrets, managed backups, alert routing, branch protection settings, and real downstream consumers.
