# ADR 005: Keep SupportNest as a Modular Monolith Before Microservices

## Status

Accepted.

## Context

SupportNest needs strong tenant isolation, RBAC, auditability, quotas, and ticket workflow correctness. Those concerns are easier to validate when the domain and transaction boundaries live in one deployable application.

The current system also needs to prove behavior under PostgreSQL locking, HTTP authorization, outbox retries, audit writes, and token lifecycle changes. Splitting those concerns across services before the boundaries are stable would increase coordination cost without improving the core product risk profile.

## Decision

SupportNest remains a modular Rails monolith for the current implementation. Modules may own their controllers, services, models, tests, and documentation, but they share the same database transaction boundary and deployment unit.

The modular boundary is expressed through namespaces and explicit service objects:

- `Organizations::*` owns tenant bootstrap.
- `Memberships::*` owns member lifecycle and token operations.
- `Tickets::*` owns ticket creation and lifecycle updates.
- `Security::*` owns authentication, authorization, and rate limiting.
- `Events::*` and `OutboundEvents::*` own durable event publication and delivery.
- `Auditing::*` owns mutation evidence.

## Options considered

| Option | Outcome | Reason |
| --- | --- | --- |
| Modular Rails monolith | Accepted | Keeps tenant isolation, RBAC, audit, and outbox transaction boundaries testable in one deployable unit |
| Microservices per domain module | Deferred | Would require distributed authorization, cross-service tenant context propagation, distributed tracing, consumer contracts, and more complex data ownership before the domain is stable |
| Shared database with multiple services | Rejected for now | Combines microservice operational cost with tight data coupling |
| Separate database per tenant | Deferred | Useful for stronger tenant isolation later, but excessive for the current portfolio slice and benchmark scope |

## Tenant isolation implications

- Tenant ownership is centralized through `organization_id`.
- Controllers must scope tenant-owned lookups through `current_organization`.
- Services can share a transaction when a mutation must update domain state, audit state, and outbox state atomically.
- PostgreSQL constraints and indexes remain available as one consistent data model.
- Future service extraction must preserve tenant context in APIs, events, logs, metrics, and audit trails.

## Consequences

- Tenant scoping and RBAC can be tested with request and integration coverage before distributed boundaries are introduced.
- The outbox remains the boundary for asynchronous side effects.
- Microservices are deferred until a specific module needs independent scaling, deployment cadence, or operational ownership.
- Service mesh, Kubernetes-specific rollout policy, and cross-service contracts stay out of the MVP.

## Revisit when

- A module has a clearly different scaling profile from the API.
- A team owns a module independently and needs separate deployment cadence.
- Event consumers require externally versioned contracts beyond the current outbox delivery.
- Tenant isolation requires database-level or infrastructure-level separation that cannot be handled inside one Rails application.
- Operational maturity includes service discovery, distributed tracing, centralized secrets, alert routing, and rollback automation.
