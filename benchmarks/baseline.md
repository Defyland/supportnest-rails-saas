# Benchmark Baseline

SupportNest defines four benchmark profiles:

## Smoke

- purpose: verify the happy path works end to end
- duration: `30s`
- concurrency: `2`
- primary path: `GET /v1/organization`, `GET /v1/tickets/:id`, and `POST /v1/tickets`

## Load

- purpose: measure steady-state API behavior
- duration: `60s`
- concurrency: `10`
- target: maintain low error rate with acceptable p95 latency

## Stress

- purpose: identify the point where latency and errors degrade materially
- duration: `80s`
- concurrency: ramp from `10` to `30`

## Spike

- purpose: reveal queueing and lock contention under abrupt traffic jumps
- duration: `60s`
- pattern: spike from `1` to `20` virtual users

## Expected outputs

- p50 latency
- p95 latency
- p99 latency
- throughput
- error rate
- notes about CPU, memory, or write contention
