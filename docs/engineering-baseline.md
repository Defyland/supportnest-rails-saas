# SupportNest Engineering Baseline

This repository follows the initiative-wide standards below.

## Mandatory outcomes

- Product-grade `README.md` with product and engineering sections
- `openapi.yaml` once the HTTP surface exists
- `docs/adr/`, `docs/architecture/`, `docs/benchmarks/`, `docs/api/`, `docs/diagrams/`, and `docs/runbooks/`
- atomic Conventional Commit history
- GitHub Actions for lint, tests, security, build, coverage, and OpenAPI validation
- observability with structured logs, metrics, traces, request IDs, and readiness endpoints
- documented k6 performance baselines

## SupportNest-specific emphasis

- strict tenant isolation on all organization-scoped resources
- RBAC with an explicit permission matrix
- billing plans, subscriptions, seat and inbox limits
- webhook idempotency
- audit log coverage for sensitive actions
- BOLA-focused security tests

## Phase 0 boundary

This repository intentionally stops before scaffolding the Rails application. The goal of this phase is only to lock scope and standards.
