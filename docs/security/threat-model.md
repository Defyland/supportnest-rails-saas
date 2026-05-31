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
| Privilege escalation | Viewer creates tickets, admin takes over owner access, or the tenant loses every reachable owner | `Security::Authorizer` enforces role permissions and membership ownership guards protect owner mutation/token paths | Low for current endpoints |
| Quota abuse | Unlimited tickets, seats, or inbox partitions exhaust shared resources | Seat, ticket, and inbox limits are enforced transactionally | Medium because limits are still local-plan fields, not billing-backed |
| Replay / duplicate side effects | Event dispatch repeats downstream operations | Outbound events store `idempotency_key`, signed webhook headers, and replay lineage | Medium until a real downstream consumer contract exists |
| Audit tampering | Sensitive actions occur without traceability | Audit logs are written inside mutation flows | Medium because no append-only storage or external sink exists yet |
| Input abuse | Invalid payloads or oversized fields pollute state | Strong params, model validations, and request tests reject malformed input | Low for current payload sizes |
| Local secret leakage | Tokens or keys appear in logs | Sensitive parameters are filtered and tokens are stored hashed | Low in the current code path |

## High-priority abuse cases

1. Cross-tenant ticket access by guessing public IDs
2. Creating memberships after seat quota exhaustion
3. Creating tickets after monthly quota exhaustion
4. Creating unbounded inbox partitions despite a tenant inbox quota
5. Reusing a suspended membership token
6. Writing unsupported outbound event types that fail silently
7. Admin-level actor mutating owner credentials or leaving a tenant without any reachable owner

## Tests mapped to threats

- BOLA and tenant isolation: `AuthorizationAndIsolationTest`
- Quota abuse: `FailureScenariosTest`
- Concurrent ticket sequence and quota abuse: `TicketConcurrencyTest`
- Invalid input: `FailureScenariosTest`
- Async failure handling: `OutboundEventDispatchJobTest` and `OutboundEventsRelayTest`
- Authorization: `AuthorizationAndIsolationTest`
- Owner continuity and owner-token mutation safeguards: `MembershipOwnershipGuardTest` and `MembershipTokenLifecycleTest`

## Next hardening steps

- device/session attribution for token use
- externalized audit sink
- row-level or schema-level tenant hardening beyond application scoping
- external broker option for the outbox relay when webhook delivery is not sufficient
- formal secret source for production deployment

## Transversal architecture additions

| Area | Risk | Current control | Required engineering discipline |
| --- | --- | --- | --- |
| BOLA | A caller guesses another tenant's `public_id` or numeric id | Controllers resolve tenant-owned records through `current_organization` | Every new endpoint needs request tests proving cross-tenant access returns `404` or `403` |
| RBAC | A lower-privilege role performs owner/admin actions | `Security::Authorizer` loads `config/authorization_matrix.yml` | Permission changes must update the matrix, docs, and authorization tests together |
| Owner continuity | Admin actions or self-demotion remove the last reachable tenant owner | Membership update, rotation, and revocation paths serialize on the organization row and enforce at least one active owner with a valid token | New owner-affecting flows must go through the same domain guard rather than relying only on controller permissions |
| API tokens | Token theft grants durable API access | Tokens are shown once, stored as SHA-256 digests, expire, rotate, and revoke | New token surfaces must never log raw tokens and must preserve `api_token_last_eight` auditability only |
| Audit log | Sensitive mutation has no durable evidence | Domain services write `AuditLog` rows inside mutation transactions | New write paths must include actor, auditable, action, tenant, and relevant metadata |
| Rate limiting | Token or IP floods degrade service | `Security::RateLimiter` stores fixed-window counters in PostgreSQL using hashed bearer-token/IP identifiers | Bypass attempts should be observable through metrics, `request_id`, and `correlation_id` |
| Authentication write amplification | High request volume turns authentication into unnecessary membership-row writes | `Membership#touch_last_seen!` only refreshes `last_seen_at` after a short interval | Short intervals improve freshness but increase write load |
| Outbound events | Duplicate delivery creates duplicate downstream side effects | Outbound events include `idempotency_key`, signed headers, retry state, and replay lineage | Consumers must treat delivery as at least once and deduplicate by idempotency key or event id |

## Architectural boundaries

- Public API requests cross into Rails through `ApplicationController`, where authentication, rate limiting, RBAC, and standardized errors are applied.
- Tenant isolation is an application-level invariant today; PostgreSQL RLS is a future hardening layer, not a current runtime dependency.
- Audit logs are application-durable in the MVP; external append-only storage is a later hardening step.
- Outbound delivery crosses an integration boundary and must be treated as untrusted by consumers until HMAC verification succeeds.
- Outbound webhook delivery fails closed when an endpoint is configured without `OUTBOUND_WEBHOOK_SECRET`; dry-run mode is only used when no endpoint is configured.
- Runtime secrets are injected through environment variables in the local production-like stack; a managed secrets backend is required before real production.
