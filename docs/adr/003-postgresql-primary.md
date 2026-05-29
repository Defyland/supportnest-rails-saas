# ADR 003: Use PostgreSQL as the primary runtime database

## Status

Accepted

## Context

SupportNest now demonstrates behavior that depends on database-level guarantees: tenant-scoped uniqueness, check constraints, row locks for ticket sequence allocation, quota enforcement under concurrent writers, and optimistic locking. SQLite is useful for a self-contained demo, but it does not represent the production concurrency model expected from a multi-tenant SaaS backend.

## Decision

Use PostgreSQL as the default database for `development`, `test`, `benchmark`, Docker Compose, and GitHub Actions. Keep SQLite as an explicit local fallback with `DATABASE_ADAPTER=sqlite3`.

## Consequences

- CI exercises the same adapter used for the seniority-critical concurrency and constraint behavior
- ticket sequence and quota tests can rely on PostgreSQL row-level locking semantics
- Docker Compose includes a PostgreSQL service for reproducible local setup
- local-only SQLite remains available for quick exploration, but it is not the authoritative verification path
