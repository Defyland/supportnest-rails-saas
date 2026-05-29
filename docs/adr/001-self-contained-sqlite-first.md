# ADR 001: Use SQLite for the self-contained implementation slice

## Status

Accepted

## Context

The challenge needs to run without external infrastructure while still demonstrating tenant isolation, validation, testing, observability, and documentation discipline.

## Decision

Use SQLite for the committed implementation slice, while keeping the architecture and documentation production-oriented.

## Consequences

- local setup stays one-command simple
- test execution remains fast in CI and on laptops
- production concurrency characteristics are underrepresented
- the roadmap explicitly calls for PostgreSQL as the next persistence step
