# Data Consistency and Transaction Design

## Transaction boundaries

### Organization bootstrap

- boundary: `Organizations::Bootstrap.call!`
- atomic work:
  - create organization
  - create owner membership
  - write audit log
  - persist outbound event
- after commit:
  - enqueue outbound dispatch job when `OUTBOX_DISPATCH_MODE=active_job`
  - otherwise leave the persisted event for the dedicated outbox relay

### Membership creation

- boundary: `Memberships::Create.call!`
- atomic work:
  - lock organization row
  - verify seat quota
  - create membership
  - write audit log
  - persist outbound event

### Membership update

- boundary: `Memberships::Update.call!`
- atomic work:
  - lock organization row
  - lock membership row
  - preserve owner-management invariants
  - verify seat quota before reactivating a suspended membership
  - update membership state or role
  - write audit log
  - persist outbound event

### Ticket creation

- boundary: `Tickets::Create.call!`
- atomic work:
  - lock organization row
  - verify monthly quota
  - evaluate `Tickets::AutoRouter` for deterministic experiment-backed support assignment
  - verify the ticket inbox does not exceed the tenant inbox quota
  - allocate next tenant ticket sequence
  - create ticket with deterministic `public_id`
  - increment `current_month_ticket_count`
  - write audit log
  - persist outbound event

### Experiment assignment and conversion

- boundary: `Experiments::Assign.call!`
- atomic work:
  - lock the experiment row
  - reject inactive experiments
  - reuse an existing `[experiment_id, subject_key]` assignment when present
  - choose a weighted variant with deterministic SHA-256 bucketing
  - persist assignment context and bucket evidence

- boundary: `Experiments::Convert.call!`
- atomic work:
  - locate the existing assignment for the tenant subject
  - reuse an existing `[organization_id, idempotency_key]` conversion when present
  - persist outcome metadata and occurrence timestamp

### Ticket update

- boundary: `Tickets::Update.call!`
- atomic work:
  - lock organization row when evaluating quota-sensitive ticket changes
  - reject new inbox values that would exceed the tenant inbox quota
  - update ticket state
  - derive workflow timestamps
  - write audit log
  - persist outbound event

### Outbound dispatch

- boundary: `OutboundEvents::Relay` or `OutboundEventDispatchJob#perform`
- atomic work:
  - claim due pending events with `FOR UPDATE SKIP LOCKED` in relay mode
  - move due pending events into `processing`
  - attempt delivery
  - mark success as `dispatched`
  - mark transient failure as `pending` with `next_attempt_at`
  - mark unsupported or exhausted events as `failed` with dead-letter metadata
  - replay failed events by creating new pending rows linked through `replayed_from_outbound_event_id`

### Rate limiting

- boundary: `Security::RateLimiter.check!`
- atomic work:
  - hash bearer-token/IP identifier before persistence
  - create or find the current fixed-window bucket
  - lock and increment the bucket counter
  - return `429` retry metadata when the configured limit is exceeded
  - expire old buckets by `expires_at`

## Indexes and constraints

- `organizations.slug` unique
- `memberships.organization_id + email` unique
- `memberships.api_token_digest` unique
- `tickets.organization_id + public_id` unique
- `tickets.organization_id + inbox` supports tenant inbox quota checks and inbox filtering
- `tickets.inbox` is constrained to a non-empty bounded key
- `experiments.organization_id + key` unique
- `experiment_variants.experiment_id + key` unique
- `experiment_assignments.experiment_id + subject_key` unique
- `experiment_conversions.organization_id + idempotency_key` unique
- `outbound_events.idempotency_key` unique
- `outbound_events.status + next_attempt_at` supports due retry polling
- `outbound_events.status + failed_at` supports dead-letter inspection
- `rate_limit_buckets.identifier_digest + window_started_at` unique for bounded fixed-window counters
- `rate_limit_buckets.expires_at` supports cleanup of expired throttling buckets
- foreign keys protect all tenant-owned relationships and membership ticket ownership

## Optimistic locking

- `tickets.lock_version` is present for optimistic locking
- ticket reads and writes return `ETag` with the current `lock_version`
- `PATCH /v1/tickets/:id` requires `If-Match` to match the current ticket version
- stale ticket updates return `409 conflict` instead of silently overwriting another agent's change

## Isolation assumptions

- PostgreSQL is the primary development, test, benchmark, and CI database
- ticket creation relies on an explicit organization row lock within a transaction to serialize ticket sequence allocation
- `test/services/ticket_concurrency_test.rb` verifies contiguous tenant ticket IDs and quota enforcement under concurrent PostgreSQL writers
- SQLite is available only as an explicit local fallback and is not the authoritative concurrency verification path

## Migration strategy

- all schema changes are additive first where possible
- new constraints must be paired with request and model tests
- benchmark-sensitive schema changes should be followed by a new local benchmark run

## Rollback strategy

- code rollback: revert to the previous deployable commit
- schema rollback: use Rails down migrations only for additive changes that are proven reversible
- data-affecting changes should have a forward-fix preference when destructive rollback would risk tenant data

## Known trade-off

The relay is production-shaped but still process-local. A cloud deployment should supervise multiple relay workers and can replace webhook delivery with SQS, Kafka, RabbitMQ, or Sidekiq while preserving the same persisted outbox state machine.
