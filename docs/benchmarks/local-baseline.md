# Local Baseline

Environment:

- Apple Silicon macOS laptop
- Ruby `3.3.6`
- Puma single-process local server
- SQLite database on local filesystem
- k6 `v1.7.1` installed via `go install`
- measurements captured on `2026-05-28`
- benchmark server started with `RATE_LIMIT_REQUESTS_PER_MINUTE=1000000`

## Results

| Scenario | p50 | p95 | p99 | Throughput | Error rate | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Smoke | 7.31ms | 16.97ms | 33.24ms | 5.87 req/s | 0.00% | 2 VUs for 30s across authenticated org read, ticket read, and ticket create; Puma peak `7.3% CPU`, `100128 KiB` RSS |
| Load | 8.01ms | 40.71ms | 86.98ms | 37.57 req/s | 0.00% | 10 VUs for 60s on the mixed read/write API profile; Puma peak `53.5% CPU`, `101504 KiB` RSS |
| Stress | 76.42ms | 171.16ms | 277.99ms | 82.36 req/s | 0.00% | ramp from 10 to 30 VUs over 80s; latency rose under SQLite write contention while ticket IDs remained collision-free; Puma peak `112.0% CPU`, `102704 KiB` RSS |
| Spike | 48.43ms | 115.41ms | 210.18ms | 68.31 req/s | 0.00% | spike from 1 to 20 VUs over 60s; no HTTP failures during the abrupt jump; Puma peak `111.2% CPU`, `102640 KiB` RSS |

Command pattern used:

```bash
BASE_URL=http://127.0.0.1:3000 \
  /Users/allanflavio/.asdf/installs/golang/1.23.3/packages/bin/k6 \
  run --summary-trend-stats="avg,min,med,max,p(90),p(95),p(99)" \
  --summary-export benchmarks/results/<scenario>-summary.json \
  benchmarks/<scenario>.js
```

Captured artifacts:

- raw k6 summaries: `benchmarks/results/*-summary.txt`
- k6 JSON exports: `benchmarks/results/*-summary.json`
- process samples: `benchmarks/results/*-resource-samples.tsv`

The first request immediately after boot showed warm-up noise in earlier runs, so the recorded baseline uses a warmed server and real tenant API traffic instead of `/up`.
