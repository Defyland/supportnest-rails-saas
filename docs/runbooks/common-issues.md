# Common Issues Runbook

## `401 unauthorized`

- confirm the request includes `Authorization: Bearer <token>`
- verify the membership is still `active`
- create a fresh membership token if the original token was lost

## `403 forbidden`

- inspect the membership role
- compare the attempted action against [docs/security/authorization-matrix.md](../security/authorization-matrix.md)
- escalate to an owner or admin for membership changes

## `422 validation_failed` on membership creation

- check for duplicate email inside the same tenant
- confirm the requested role is not `owner`
- verify the organization seat limit has not been reached

## `422 validation_failed` on ticket creation

- confirm required fields are present
- confirm the assignee belongs to the same tenant
- verify the monthly ticket quota has not been exhausted

## `503` on `/ready`

- check the database file path and file permissions
- run `bin/rails db:prepare`
- inspect application logs for migration drift or database corruption

## Failed outbound event dispatch

- inspect the `outbound_events` table for `status = failed`
- review `last_error` for unsupported or malformed event payloads
- replay manually by re-enqueueing `OutboundEventDispatchJob`
