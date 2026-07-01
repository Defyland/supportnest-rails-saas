# Local Baseline

Environment:

- Apple Silicon macOS laptop
- Ruby `3.4.9`
- Puma single-process local server
- PostgreSQL local database reset per scenario by `bin/benchmark`
- k6 `v1.7.1` installed via `go install`
- measurements refreshed on `2026-07-01`
- benchmark server started by `bin/benchmark` with `RATE_LIMIT_REQUESTS_PER_MINUTE=100000`
- the benchmark harness now defaults to `BENCHMARK_PORT=3203` so a reviewer can keep the normal app on `localhost:3000` without colliding with the managed benchmark server

## Results

| Scenario | p50 | p95 | p99 | Throughput | Error rate | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Smoke | 27.58ms | 88.93ms | 213.30ms | 5.37 req/s | 0.00% | 2 VUs for 30s across authenticated org read, ticket read, and ticket create; Puma peak `68.3% CPU`, `216464 KiB` RSS |
| Load | 43.21ms | 434.12ms | 1079.48ms | 27.70 req/s | 0.00% | 10 VUs for 60s on the mixed read/write API profile; Puma peak `82.5% CPU`, `262544 KiB` RSS |
| Stress | 43.48ms | 214.51ms | 1681.25ms | 73.89 req/s | 0.00% | ramp from 10 to 30 VUs over 80s; PostgreSQL row locking kept ticket IDs collision-free; Puma peak `80.8% CPU`, `292720 KiB` RSS |
| Spike | 49.40ms | 164.90ms | 258.02ms | 62.66 req/s | 0.00% | spike from 1 to 20 VUs over 60s; no HTTP failures during the abrupt jump; Puma peak `82.0% CPU`, `290016 KiB` RSS |

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
