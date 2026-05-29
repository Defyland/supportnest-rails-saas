# Requirement Closure Plan

This document records the remaining gaps identified after the first functional slice and the execution plan used to close them against `specs/general-project-spec.md`.

## Initial gap audit

| Requirement area | Gap found in current state | Execution plan | Status |
| --- | --- | --- | --- |
| Security baseline | Threat model and authorization matrix were only mentioned indirectly | Add dedicated security docs and link them from the README | Complete |
| Observability baseline | No committed Grafana dashboard definition | Add a versioned Grafana dashboard JSON using current Prometheus metrics | Complete |
| Data and transaction baseline | Transaction boundaries, isolation assumptions, migration strategy, and rollback strategy were not explicit | Add a dedicated data consistency document | Complete |
| Performance baseline | Only the smoke result was measured; load, stress, and spike were still pending | Rewrite k6 scenarios to hit real authenticated API flows and capture all required results | Complete |
| Performance evidence quality | The original benchmarks only hit `/up`, not tenant API workflows | Benchmark organization bootstrap plus tenant-authenticated ticket reads and writes | Complete |
| Failure simulation coverage | Some documented failures were not covered by request tests | Add request tests for seat limit exhaustion, ticket quota exhaustion, and invalid input | Complete |
| Consistency under load | Ticket public IDs were derived from `organization.tickets.count + 1`, which is unsafe under concurrent writes | Add an organization ticket sequence and allocate IDs inside the ticket creation transaction | Complete |
| Commit history standard | Work was still only in the working tree | Create atomic Conventional Commits after verification succeeds | Complete |

## Execution notes

1. Close correctness and consistency gaps before collecting benchmark numbers.
2. Add missing documentation artifacts required by the spec.
3. Run benchmarks against a warmed local server with rate limiting raised for measurement.
4. Record benchmark outputs, CPU and memory notes, and update repository documentation.
5. Create atomic commits that tell the implementation story.

## Completion criteria

This plan is now closed with repository evidence for every row above.
