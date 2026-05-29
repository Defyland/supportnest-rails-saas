# Outbox Relay Runbook

## Symptoms

- `supportnest_outbound_events_total{status="failed"}` increases
- downstream consumers report missing events
- `bin/outbox dlq` shows failed events
- relay logs include repeated delivery failures

## Triage

1. Check API readiness: `curl -fsS http://localhost:3000/ready`.
2. Inspect dead letters: `bin/outbox dlq --limit 20`.
3. Inspect pending backlog in PostgreSQL:

   ```sql
   SELECT status, count(*)
   FROM outbound_events
   GROUP BY status
   ORDER BY status;
   ```

4. Check for stale processing events:

   ```sql
   SELECT id, event_type, processing_started_at, relay_worker_id
   FROM outbound_events
   WHERE status = 'processing'
   ORDER BY processing_started_at;
   ```

## Recovery

- transient downstream outage: leave events as `pending`; relay backoff will retry
- stuck processing rows: run `bin/outbox relay --once`; the relay requeues stale processing events before claiming due work
- dead-letter replay: run `bin/outbox replay <event_id> --requested-by <operator>` after validating the consumer is healthy
- immediate replay through Active Job: add `--dispatch` when the API is not in relay mode

## Safety Rules

- do not mutate `failed` rows in place; replay creates a new event with lineage
- do not delete dead letters until incident review and retention requirements are satisfied
- consumers must deduplicate using the `Idempotency-Key` header
- validate `X-SupportNest-Signature` using `OUTBOUND_WEBHOOK_SECRET`
