# ADR 007: Publish The Repo Under MIT

## Status

Accepted

## Context

`supportnest-rails-saas` is already a public teaching asset with production
readiness, runbook, and architecture material. An explicit reuse surface is
still missing while the repo remains intentionally visible for study and
adaptation.

## Decision

Add an explicit MIT license and reference it from the README.

## Consequences

Positive:

- reuse and adaptation become explicit for public readers;
- the legal surface matches the repo's portfolio purpose;
- downstream study assets can cite a clear reuse contract.

Negative:

- broad reuse is allowed with limited reciprocity;
- the license does not require derivative changes to stay public.

## Verification evidence

- `PATH=/Users/allanflavio/.asdf/shims:$PATH /Users/allanflavio/Documents/projects/PERSONAL/backend-challenges/eval-harness/bin/eval-harness . --output /tmp/supportnest-ai-ready.md`
