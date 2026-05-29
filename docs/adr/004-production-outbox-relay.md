# ADR 004: Production outbox relay with dead-letter and replay

## Status

Accepted

## Context

The initial outbox path persisted events and dispatched them through Active Job. That proved the transactional outbox pattern, but production operation needs explicit ownership of event polling, concurrent worker safety, dead-letter handling, replay controls, and delivery idempotency.

## Decision

Use a dedicated relay process for production-style delivery:

- API writes persist `OutboundEvent` records inside the same business transaction
- `OUTBOX_DISPATCH_MODE=relay` disables immediate Active Job enqueue from the API process
- `bin/outbox relay --loop` claims due events with PostgreSQL `FOR UPDATE SKIP LOCKED`
- claimed events move to `processing` with a `relay_worker_id`
- transient failures return to `pending` with exponential `next_attempt_at`
- exhausted or unsupported events move to the dead-letter queue with `failed_at` and `dead_letter_reason`
- `bin/outbox replay EVENT_ID` creates a new pending event linked to the failed source event
- webhook delivery includes HMAC signatures and idempotency headers

## Consequences

- multiple relay workers can run safely without double-dispatching the same event
- operational replay preserves lineage instead of mutating dead-letter history
- consumers can deduplicate with `Idempotency-Key`
- production still needs a durable worker supervisor and a real downstream webhook/broker endpoint
