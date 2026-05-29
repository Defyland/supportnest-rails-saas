# Disaster Recovery Runbook

## Targets

| Measure | Target for this slice |
| --- | --- |
| RPO | 15 minutes with managed PostgreSQL PITR |
| RTO | 60 minutes for API restore in a fresh environment |
| Backup verification | monthly restore drill |

## Backup Expectations

- enable automated PostgreSQL backups and point-in-time recovery in the managed database provider
- keep application secrets in a secrets manager, not only in deployment variables
- retain audit logs and dead-letter events according to tenant data-retention policy
- include `db/schema.rb`, migrations, and release tags in deployment artifacts

## Restore Drill

1. Provision a clean PostgreSQL instance.
2. Restore the latest backup or PITR snapshot.
3. Deploy the matching application release tag.
4. Run migrations only after confirming release compatibility.
5. Check `/ready`, tenant bootstrap read paths, and outbox relay status.
6. Run `bin/outbox dlq` and replay only events approved by incident command.

## Rollback Rules

- prefer forward fixes for schema/data issues after migrations have run in production
- use blue/green or rolling deploy rollback for app-only regressions
- pause outbox relay before replaying or backfilling large event sets
