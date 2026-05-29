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
  - enqueue outbound dispatch job

### Membership creation

- boundary: `Memberships::Create.call!`
- atomic work:
  - lock organization row
  - verify seat quota
  - create membership
  - write audit log
  - persist outbound event

### Ticket creation

- boundary: `Tickets::Create.call!`
- atomic work:
  - lock organization row
  - verify monthly quota
  - allocate next tenant ticket sequence
  - create ticket with deterministic `public_id`
  - increment `current_month_ticket_count`
  - write audit log
  - persist outbound event

### Ticket update

- boundary: `Tickets::Update.call!`
- atomic work:
  - update ticket state
  - derive workflow timestamps
  - write audit log
  - persist outbound event

## Indexes and constraints

- `organizations.slug` unique
- `memberships.organization_id + email` unique
- `memberships.api_token_digest` unique
- `tickets.organization_id + public_id` unique
- `outbound_events.idempotency_key` unique
- foreign keys protect all tenant-owned relationships and membership ticket ownership

## Optimistic locking

- `tickets.lock_version` is present for optimistic locking
- ticket reads and writes return `ETag` with the current `lock_version`
- `PATCH /v1/tickets/:id` requires `If-Match` to match the current ticket version
- stale ticket updates return `409 conflict` instead of silently overwriting another agent's change

## Isolation assumptions

- current local baseline uses SQLite transactions
- ticket creation relies on an explicit organization row lock within a transaction to serialize ticket sequence allocation
- production should move to PostgreSQL and revalidate lock behavior under real concurrent writers

## Migration strategy

- all schema changes are additive first where possible
- new constraints must be paired with request and model tests
- benchmark-sensitive schema changes should be followed by a new local benchmark run

## Rollback strategy

- code rollback: revert to the previous deployable commit
- schema rollback: use Rails down migrations only for additive changes that are proven reversible
- data-affecting changes should have a forward-fix preference when destructive rollback would risk tenant data

## Known trade-off

SQLite is acceptable for the self-contained challenge but is not the target production database for this design.
