# Railway Deploy

This guide configures SupportNest as a single-service Railway deployment for
public demo and reviewer evaluation.

## Runtime shape

- builder: `Dockerfile`
- activation health check: `/up`
- readiness endpoint available separately at `/ready`
- database migration/bootstrap: `bin/docker-entrypoint` runs `db:prepare`
- outbound dispatch mode: `OUTBOX_DISPATCH_MODE=active_job` keeps async delivery
  in the web process for the demo topology

The Railway path is intentionally smaller than the prod-like Compose topology.
It proves the product surface without requiring a dedicated relay process.

## Required variables

Set these in Railway:

```bash
RAILS_ENV=production
DATABASE_URL=<managed-postgres-url>
RAILS_MASTER_KEY=<local config/master.key>
SECRET_KEY_BASE=<generated-secret>
RAILS_SERVE_STATIC_FILES=true
RAILS_ALLOWED_HOSTS=<your-public-railway-domain>
OUTBOX_DISPATCH_MODE=active_job
```

Optional variables:

```bash
OTEL_EXPORTER_OTLP_ENDPOINT=<collector-endpoint>
```

## Five-minute verification

After deploy:

```bash
curl -fsS "$RAILWAY_PUBLIC_DOMAIN/up"
curl -fsS "$RAILWAY_PUBLIC_DOMAIN/ready"
curl -fsS "$RAILWAY_PUBLIC_DOMAIN/metrics"
```

Then bootstrap one tenant and exercise one membership mutation plus one ticket
mutation from [docs/api/http-examples.md](docs/api/http-examples.md).

## Limits

- This is a demo topology, not the final production shape.
- Outbound delivery runs through `active_job` instead of the dedicated relay.
- Reviewer hosting still needs real secret management and host allowlisting.
