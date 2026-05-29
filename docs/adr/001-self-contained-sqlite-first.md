# ADR 001: Use SQLite for the self-contained implementation slice

## Status

Superseded by [ADR 003](003-postgresql-primary.md)

## Context

The original challenge needed to run without external infrastructure while still demonstrating tenant isolation, validation, testing, observability, and documentation discipline.

## Decision

Use SQLite for the initial committed implementation slice, while keeping the architecture and documentation production-oriented.

## Consequences

- local setup stays one-command simple
- test execution remains fast in CI and on laptops
- production concurrency characteristics are underrepresented
- the roadmap explicitly called for PostgreSQL as the next persistence step

This decision no longer describes the primary runtime path. SQLite remains available only through `DATABASE_ADAPTER=sqlite3`.
