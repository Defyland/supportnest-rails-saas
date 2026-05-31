# Deployment Readiness

SupportNest currently documents and tests production-style behavior through Docker, health checks, readiness checks, bounded metrics, database-backed rate limiting, relay-owned outbox dispatch, and runtime secrets. This is enough for the portfolio slice to demonstrate operational shape without making Kubernetes the main project.

## Current posture

- Containerized Rails runtime.
- `/up`, `/ready`, and `/metrics` endpoints.
- Bounded Prometheus metrics storage that aggregates counters and histogram buckets instead of retaining request samples.
- PostgreSQL-backed fixed-window rate limiting with hashed token/IP identifiers.
- Production default that leaves outbox dispatch to the dedicated relay unless explicitly overridden.
- Webhook delivery refuses to boot with a configured endpoint and missing signing secret.
- Runtime environment variables for secrets.
- Multi-stage runtime with Non-root container execution.
- Rails Host Authorization is enabled from the `RAILS_ALLOWED_HOSTS` allowlist.
- CI coverage for tests, security checks, and image validation.

## Deferred platform work

- Kubernetes manifests, Helm charts, and Terraform are deferred until the application has a stable production deployment target.
- Blue/green and canary rollout strategy should be documented once a real ingress and database migration workflow exist.
- Secret manager integration should replace local environment variables for production.
