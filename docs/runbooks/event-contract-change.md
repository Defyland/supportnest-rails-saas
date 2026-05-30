# Event Contract Change

Use this runbook when a SupportNest outbound event needs a schema change.

## Checks

- Confirm the event is listed in `docs/events/README.md`.
- Add optional fields first; do not remove or rename existing fields in v1.
- Verify downstream consumers can deduplicate by `X-SupportNest-Event-ID` or `Idempotency-Key`.
- Confirm tenant data remains scoped by `organization_id`.
- Update tests that assert outbox payload shape.

## Rollback

- Stop dispatch if consumers reject the payload.
- Restore the previous producer payload shape.
- Replay failed outbox rows only after confirming the old schema is accepted.
