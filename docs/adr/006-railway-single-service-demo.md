# ADR 006: Railway Single-Service Demo Deployment

## Status

Accepted

## Context

SupportNest already had a credible local and prod-like topology, but evaluator
readiness still lacked a small public deployment path. The product also defaults
to a dedicated outbox relay in production, which is the right operational shape
for the full platform but too heavy for a reviewer demo.

## Options considered

- Keep Compose and Docker as the only runnable surfaces.
  Rejected because reviewers would still need local infra to validate the app.
- Add a Railway path that also requires a second relay service.
  Rejected because it increases reviewer setup and spreads the demo across more
  than one service.
- Add a Railway single-service demo and switch outbound dispatch to `active_job`.
  Chosen because it keeps PostgreSQL, preserves the main API contract, and makes
  the public review path small.

## Decision

Add `railway.json`, `RAILWAY_DEPLOY.md`, and `bin/docker-entrypoint`, and
document Railway as a single-service demo topology using managed PostgreSQL plus
`OUTBOX_DISPATCH_MODE=active_job`.

## Consequences

Positive:

- the repo gains a lightweight public demo path;
- PostgreSQL remains the production database instead of introducing a second
  persistence story;
- boot-time `db:prepare` is explicit for container deploys.

Negative:

- outbound delivery no longer matches the dedicated relay production default;
- the Railway path is a demo topology, not the final operational split;
- real production still needs supervised relay workers and alert routing.

## Verification evidence

- `PATH=/Users/allanflavio/.asdf/shims:$PATH bin/ci`
- `PATH=/Users/allanflavio/.asdf/shims:$PATH /Users/allanflavio/Documents/projects/PERSONAL/backend-challenges/eval-harness/bin/eval-harness . --output /tmp/supportnest-ai-ready.md`
