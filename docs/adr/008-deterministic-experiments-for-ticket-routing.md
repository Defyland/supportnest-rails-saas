# ADR 008: Deterministic Experiments for Ticket Routing

## Status

Accepted.

## Context

SupportNest now needs to demonstrate product experimentation and support-flow
automation without weakening tenant isolation or the ticket write path. The
platform already has tenant-scoped memberships, optimistic ticket locking,
audit logs, and an outbox. The missing capability was an executable way to
compare operational policies, such as simple load balancing versus SLA-weighted
routing, while preserving stable user assignment and retry-safe conversion
tracking.

The implementation must be useful as a senior backend evidence point:

- assignment must be deterministic and tenant-scoped;
- conversion tracking must be idempotent;
- ticket creation must stay available if an experiment is absent or misconfigured;
- routing decisions must leave audit/outbox evidence;
- the public API contract must be versioned in OpenAPI and covered by tests.

## Decision

SupportNest stores experiments, variants, subject assignments, and conversions
inside the Rails modular monolith.

`Experiments::Assign` deterministically buckets a tenant subject with
`SHA256(experiment.id + subject_key)` and weighted variants. Existing
assignments are immutable from the caller's perspective: later weight changes
do not move a subject to a different variant.

`Experiments::Convert` records conversion events through a tenant-scoped
`idempotency_key`, so client retries do not duplicate analytics facts.

`Tickets::AutoRouter` uses the active `ticket-auto-routing` experiment when it
exists. Supported variants map to concrete algorithms:

- `least-open-tickets`: choose the active support member with the fewest open or
  pending tickets.
- `sla-priority`: choose the active support member with the lowest weighted
  open workload, where urgent/high tickets cost more than normal/low tickets.

Only active `admin` and `agent` memberships are eligible for auto-assignment.
If no eligible support member exists, or if the experiment is unavailable, the
ticket is still created and the router falls back to a safe default decision.

## Options considered

| Option | Outcome | Reason |
| --- | --- | --- |
| Deterministic database-backed experiments | Accepted | Gives stable assignment, idempotent conversions, auditability, and local testability without external analytics infrastructure |
| In-memory feature flags | Rejected | Easy to demo but not durable, not tenant-scoped, and not enough evidence for A/B testing at scale |
| External experimentation SaaS | Deferred | Useful later, but introduces credentials and vendor behavior that cannot be verified in this repository |
| Random assignment per request | Rejected | Breaks experiment integrity because the same subject can move between variants |
| Auto-assign owners too | Rejected | Owners administer the tenant; default support queues should target `admin` and `agent` roles only |

## Pros

- Deterministic assignment survives retries and multi-process deployments.
- Weighted variants support A/B and multivariate experiments with one code path.
- Idempotent conversions make client retries safe.
- Routing evidence is attached to `ticket.created` audit and outbox payloads.
- The feature is covered by model, service, integration, OpenAPI, and repository
  compliance tests.

## Cons

- The first version does not expose experiment management CRUD; operators seed
  or manage experiments through internal Rails tasks/admin tooling later.
- Assignment state adds tables and retention concerns that a pure feature flag
  would avoid.
- The router uses aggregate workload scores, not availability calendars or
  agent skill matrices.
- The experiment is intentionally fail-open for ticket creation, so bad
  experiment configuration falls back instead of blocking support intake.

## Consequences

- Product experimentation is now part of the domain model, not README-only
  narrative.
- Any future routing policy must be represented as a supported variant key and
  tested as an algorithm, not as arbitrary runtime code.
- If experiment volume grows, retention and aggregation jobs should be added
  before assignments/conversions become unbounded analytics storage.
- If a separate experimentation service is introduced later, it must preserve
  tenant context, deterministic assignment, idempotent conversions, and API
  compatibility.

## Evidence

- `test/services/experiments_assignment_test.rb` proves deterministic assignment,
  assignment stability after weight changes, inactive experiment handling, and
  idempotent conversions.
- `test/services/tickets_auto_router_test.rb` proves default load-based routing,
  SLA-weighted routing through an assigned experiment variant, no-candidate
  behavior, and audit/outbox routing evidence.
- `test/integration/experiments_flow_test.rb` proves authenticated REST
  assignment/conversion flows and viewer authorization denial.
- `test/integration/openapi_response_contract_test.rb` proves the new response
  payloads satisfy the OpenAPI schema.
- `openapi.yaml` documents the external assignment/conversion contract.

Focused verification run:

```bash
PATH=/Users/allanflavio/.asdf/shims:$PATH bin/rails test \
  test/models/experiment_test.rb \
  test/services/experiments_assignment_test.rb \
  test/integration/experiments_flow_test.rb \
  test/integration/openapi_response_contract_test.rb

PATH=/Users/allanflavio/.asdf/shims:$PATH bin/rails test \
  test/services/tickets_auto_router_test.rb \
  test/integration/tickets_flow_test.rb \
  test/services/mutation_transaction_boundaries_test.rb \
  test/services/ticket_concurrency_test.rb
```
