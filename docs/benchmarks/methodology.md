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

The committed benchmark runs use `k6 v1.7.1` installed via `go install`. The benchmark runner uses the isolated `benchmark` Rails environment and raises `RATE_LIMIT_REQUESTS_PER_MINUTE` for the managed server to avoid benchmark noise from intentional throttling.

`bin/benchmark <scenario>` performs the full capture flow:

- resets and migrates the benchmark database unless `BENCHMARK_PREPARE_DB=0`
- starts Puma unless `BASE_URL` is provided or `BENCHMARK_SKIP_SERVER=1`
- waits for `/ready` before running k6
- exports trend stats with `med`, `p(95)`, and `p(99)` enabled
- stores the raw k6 text summary and JSON summary under `benchmarks/results/`
- samples the Puma process once per second with `ps` to capture `%CPU` and RSS peaks
- writes the managed server log as `benchmarks/results/<scenario>-server.log`

Use `bin/benchmark smoke`, `bin/benchmark load`, `bin/benchmark stress`, or `bin/benchmark spike` to run the same capture flow. Set `K6_BIN` if k6 is not on `PATH`.

For an already running server, set `BASE_URL` and optionally `SERVER_PID`; in that mode the runner does not own server startup or shutdown.
