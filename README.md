# SupportNest

Multi-tenant B2B helpdesk SaaS built as a Rails API portfolio project.

## Status

Phase 0 bootstrap only. This repository currently establishes naming, scope, documentation structure, and engineering expectations. It does not yet contain a Rails application scaffold.

## Product intent

SupportNest is planned as a helpdesk SaaS for B2B teams, focused on tenant isolation, RBAC, billing entitlements, ticket workflows, and auditability.

## Planned stack

- Ruby on Rails API
- PostgreSQL
- Redis
- RabbitMQ or a Rails-native background job strategy
- OpenTelemetry
- Prometheus and Grafana
- Docker Compose
- k6

## Engineering focus

This project is meant to demonstrate:

- serious multi-tenancy boundaries
- role-based authorization
- billing and plan entitlements
- a modular monolith design
- failure-aware background processing
- request, integration, and security testing

## Bootstrap contents

- repository initialized and synchronized with GitHub
- mandatory documentation folders created
- baseline engineering spec captured in `docs/engineering-baseline.md`

## Next phase

The first implementation slice should prioritize organizations, memberships, RBAC, tickets, and tenant-isolation tests.
