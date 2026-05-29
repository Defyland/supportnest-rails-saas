# Threat Model

## Scope

This model covers the current SupportNest slice:

- organization bootstrap
- membership token authentication
- role-based access control
- ticket creation and updates
- audit logging
- outbound event persistence and dispatch

## Assets

- tenant-scoped ticket data
- membership API tokens
- audit evidence
- outbound integration payloads
- organization quota state

## Trust boundaries

1. Public HTTP API boundary
2. Rails application boundary
3. PostgreSQL persistence boundary
4. Async job boundary between request path and outbound dispatch

## Primary threats

| Threat | Example | Current mitigation | Residual risk |
| --- | --- | --- | --- |
| BOLA / tenant breakout | Tenant A reads `TCK-000001` from tenant B | Controller lookups are scoped through `current_organization` | Medium if future endpoints forget tenant scoping |
| Token theft | Leaked bearer token grants ticket access | Raw tokens are only shown once, stored as SHA-256 digests, expire after a fixed TTL, and can be rotated or revoked | Medium without device/session-level attribution |
| Privilege escalation | Viewer creates tickets or edits memberships | `Security::Authorizer` enforces role permissions | Low for current endpoints |
| Quota abuse | Unlimited tickets or seats exhaust shared resources | Seat and ticket limits are enforced transactionally | Medium because limits are still local-plan fields, not billing-backed |
| Replay / duplicate side effects | Event dispatch repeats downstream operations | Outbound events store `idempotency_key` and `correlation_id` | Medium until a real broker and downstream consumer contract exist |
| Audit tampering | Sensitive actions occur without traceability | Audit logs are written inside mutation flows | Medium because no append-only storage or external sink exists yet |
| Input abuse | Invalid payloads or oversized fields pollute state | Strong params, model validations, and request tests reject malformed input | Low for current payload sizes |
| Local secret leakage | Tokens or keys appear in logs | Sensitive parameters are filtered and tokens are stored hashed | Low in the current code path |

## High-priority abuse cases

1. Cross-tenant ticket access by guessing public IDs
2. Creating memberships after seat quota exhaustion
3. Creating tickets after monthly quota exhaustion
4. Reusing a suspended membership token
5. Writing unsupported outbound event types that fail silently

## Tests mapped to threats

- BOLA and tenant isolation: `AuthorizationAndIsolationTest`
- Quota abuse: `FailureScenariosTest`
- Concurrent ticket sequence and quota abuse: `TicketConcurrencyTest`
- Invalid input: `FailureScenariosTest`
- Async failure handling: `OutboundEventDispatchJobTest`
- Authorization: `AuthorizationAndIsolationTest`

## Next hardening steps

- device/session attribution for token use
- externalized audit sink
- row-level or schema-level tenant hardening beyond application scoping
- broker-backed outbox relay with retries and dead-letter handling
- formal secret source for production deployment
