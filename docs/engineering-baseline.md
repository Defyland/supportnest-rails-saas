# SupportNest Engineering Baseline

This repository now implements the first functional slice of the SupportNest platform and keeps the initiative-wide standards active as repository policy.

## Repository commitments

- product-grade `README.md` with both product and engineering depth
- `openapi.yaml` as the source of truth for the HTTP contract
- `docs/adr/`, `docs/architecture/`, `docs/benchmarks/`, `docs/api/`, `docs/diagrams/`, and `docs/runbooks/`
- Conventional Commit history for future changes
- GitHub Actions coverage for lint, tests, security, SBOM generation, Docker build, coverage artifact upload, and OpenAPI linting
- optional Trivy-based container scanning through `bin/container-scan`
- non-root Docker runtime with secrets injected at runtime
- PostgreSQL-backed development, test, benchmark, Docker Compose, and CI paths
- structured logs, request metadata, metrics, traces, and readiness endpoints
- prod-like Compose stack with app, outbox relay, PostgreSQL, OTLP collector, Prometheus alerts, and Grafana provisioning
- committed k6 scenarios and a documented local baseline workflow
- automated `bin/benchmark` runner for database prep, managed server startup, k6 execution, and CPU/RSS capture
- senior technical validation with executed fixes in [senior-technical-validation.md](senior-technical-validation.md)

## SupportNest-specific emphasis

- strict tenant isolation on every organization-scoped lookup
- RBAC with an explicit membership permission matrix
- plan-based seat and ticket quotas
- PostgreSQL row-lock tests for concurrent ticket sequence and quota behavior
- audit log coverage for security-sensitive mutations
- BOLA-oriented request tests
- outbox-style async event persistence before dispatch
- dedicated outbox relay with `FOR UPDATE SKIP LOCKED`, dead-letter handling, replay lineage, and signed webhook delivery
