# Production Readiness

This repository is a portfolio-grade production-readiness slice. It does not claim to replace a real cloud deployment, but it implements the highest-signal controls that can be proven locally and in CI.

## Implemented Controls

| Area | Implemented evidence |
| --- | --- |
| Database | PostgreSQL is the primary dev/test/benchmark/CI database; SQLite is explicit fallback only |
| Consistency | ticket sequence and quota concurrency tests run against PostgreSQL row locks |
| Outbox | dedicated relay, `FOR UPDATE SKIP LOCKED`, retry backoff, dead-letter metadata, replay lineage, production relay default, and HMAC webhook delivery with fail-closed secret configuration |
| Operations | `docker-compose.prod-like.yml` runs app, outbox relay, PostgreSQL, OTLP collector, Prometheus, and Grafana |
| Observability | `/ready`, `/metrics`, bounded Prometheus histograms/counters, OpenTelemetry OTLP export, Prometheus alerts, and Grafana provisioning |
| Security | token lifecycle, hashed API tokens, RBAC matrix, PostgreSQL-backed rate limiting with hashed identifiers, non-root multi-stage Docker runtime, Brakeman, bundler-audit, SBOM generation, and optional container scanning script |
| Contracts | OpenAPI lint, bounded pagination contracts, plus representative response contract tests |
| Performance | reproducible `bin/benchmark` runner and committed k6 artifacts |

## Simulated Or Local-Only Controls

| Area | Reason |
| --- | --- |
| Secrets manager | prod-like compose uses placeholder env vars; cloud deployment should use AWS Secrets Manager, GCP Secret Manager, Doppler, Vault, or platform-native secrets. Runtime code now fails closed if a webhook endpoint is configured without `OUTBOUND_WEBHOOK_SECRET` |
| Log aggregation | structured logs are emitted, but no managed log backend is attached |
| Alert routing | Prometheus alert rules exist, but Alertmanager/PagerDuty routing is intentionally not configured |
| Backups | restore procedures are documented; actual snapshots depend on the managed PostgreSQL provider |
| Branch protection | required checks must be enforced in GitHub repository settings, outside the codebase |

## Production Promotion Checklist

1. Configure managed PostgreSQL with automated backups, PITR, and restore drill evidence.
2. Replace prod-like placeholder secrets with a real secrets manager.
3. Keep `OUTBOX_DISPATCH_MODE=relay` for API containers and run at least two supervised relay workers.
4. Configure `OUTBOUND_WEBHOOK_URL` and `OUTBOUND_WEBHOOK_SECRET`; boot should fail fast without the secret, and consumers must validate HMAC signatures.
5. Wire OTLP, logs, Prometheus alerts, and dashboard provisioning into the production observability stack.
6. Enforce GitHub branch protection, required CI checks, signed release tags, and review requirements.
7. Generate SBOMs per release with `bin/sbom` and scan built images with `bin/container-scan`.
8. Run `bin/benchmark load|stress|spike` against production-like infrastructure before capacity claims.
9. Inject secrets through the deployment platform or a secrets manager; do not bake production secrets into the image.

## Local Prod-Like Run

```bash
docker compose -f docker-compose.prod-like.yml up --build
```

Useful endpoints:

- API: `http://localhost:3000`
- Prometheus: `http://localhost:9090`
- Grafana: `http://localhost:3001` with `admin/admin`

Outbox operations:

```bash
bin/outbox relay --once
bin/outbox dlq
bin/outbox replay <failed_event_id> --requested-by operator
```
