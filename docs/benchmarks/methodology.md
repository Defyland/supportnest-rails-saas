# Benchmark Methodology

SupportNest ships k6 scenarios for four baseline shapes:

- smoke: prove the happy path works under light concurrency
- load: measure steady-state latency and throughput
- stress: push past expected load to observe degradation
- spike: jump abruptly to reveal queueing and saturation behavior

## Endpoints under test

- `POST /v1/organizations` during benchmark setup
- `GET /v1/organization`
- `GET /v1/tickets/:public_id`
- `POST /v1/tickets`

## Metrics collected

- p50 latency
- p95 latency
- p99 latency
- throughput
- error rate
- qualitative CPU and memory notes

## Execution note

The committed benchmark runs use `k6 v1.7.1` installed via `go install`. Measurements are taken against a warmed local server with `RATE_LIMIT_REQUESTS_PER_MINUTE` raised to avoid benchmark noise from intentional throttling.

Each committed run also:

- exports trend stats with `med`, `p(95)`, and `p(99)` enabled
- stores the raw k6 text summary and JSON summary under `benchmarks/results/`
- samples the Puma process once per second with `ps` to capture `%CPU` and RSS peaks
