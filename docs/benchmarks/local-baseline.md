# Local Baseline

Environment:

- Apple Silicon macOS laptop
- Ruby `3.3.6`
- Puma single-process local server
- PostgreSQL local database reset per scenario by `bin/benchmark`
- k6 `v1.7.1` installed via `go install`
- measurements refreshed on `2026-05-29`
- benchmark server started by `bin/benchmark` with `RATE_LIMIT_REQUESTS_PER_MINUTE=100000`

## Results

| Scenario | p50 | p95 | p99 | Throughput | Error rate | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Smoke | 11.53ms | 46.74ms | 142.53ms | 5.71 req/s | 0.00% | 2 VUs for 30s across authenticated org read, ticket read, and ticket create; Puma peak `44.4% CPU`, `105296 KiB` RSS |
| Load | 13.90ms | 49.41ms | 84.00ms | 36.79 req/s | 0.00% | 10 VUs for 60s on the mixed read/write API profile; Puma peak `76.3% CPU`, `111120 KiB` RSS |
| Stress | 22.33ms | 91.78ms | 205.44ms | 110.15 req/s | 0.00% | ramp from 10 to 30 VUs over 80s; PostgreSQL row locking kept ticket IDs collision-free; Puma peak `86.1% CPU`, `101664 KiB` RSS |
| Spike | 19.97ms | 105.95ms | 185.30ms | 78.56 req/s | 0.00% | spike from 1 to 20 VUs over 60s; no HTTP failures during the abrupt jump; Puma peak `78.8% CPU`, `105936 KiB` RSS |

Command pattern used:

```bash
bin/benchmark smoke
bin/benchmark load
bin/benchmark stress
bin/benchmark spike
```

Captured artifacts:

- raw k6 summaries: `benchmarks/results/*-summary.txt`
- k6 JSON exports: `benchmarks/results/*-summary.json`
- process samples: `benchmarks/results/*-resource-samples.tsv`
- managed server logs: `benchmarks/results/*-server.log`

The first request immediately after boot showed warm-up noise in earlier runs, so the recorded baseline uses a warmed server and real tenant API traffic instead of `/up`.
