# Architecture Overview

SupportNest is organized as a Rails API modular monolith with explicit service boundaries.

## Request flow

1. `Middleware::RequestContext` extracts request metadata and correlation state.
2. `Middleware::Metrics` measures latency and request volume.
3. `ApplicationController` enforces rate limiting and bearer authentication.
4. RBAC checks gate controller actions by membership role.
5. Application services perform transactional writes.
6. `Auditing::Logger` persists audit evidence.
7. `Events::Publisher` stores an outbox record and enqueues dispatch after commit.

## Subsystems

- **Identity and access**: membership-scoped token auth plus RBAC
- **Ticketing**: create, read, update, and workflow timestamps
- **Auditability**: immutable audit records for sensitive mutations
- **Async integration**: outbox plus Active Job dispatcher
- **Observability**: JSON logs, readiness, metrics, and traces

## Boundaries

- Controllers never query outside `current_organization` for tenant-owned resources.
- Services own business workflows and side effects.
- Models keep local invariants such as normalization and relationship checks.
