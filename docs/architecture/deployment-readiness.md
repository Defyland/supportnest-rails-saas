# Deployment Readiness

SupportNest currently documents production-style behavior through Docker, health checks, readiness checks, metrics, and runtime secrets. This is enough for the portfolio slice to demonstrate operational shape without making Kubernetes the main project.

## Current posture

- Containerized Rails runtime.
- `/up`, `/ready`, and `/metrics` endpoints.
- Runtime environment variables for secrets.
- Non-root container execution.
- CI coverage for tests, security checks, and image validation.

## Deferred platform work

- Kubernetes manifests, Helm charts, and Terraform are deferred until the application has a stable production deployment target.
- Blue/green and canary rollout strategy should be documented once a real ingress and database migration workflow exist.
- Secret manager integration should replace local environment variables for production.
