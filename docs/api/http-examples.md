# HTTP Examples

## Bootstrap an organization

```bash
curl -X POST http://localhost:3000/v1/organizations \
  -H "Content-Type: application/json" \
  -d '{
    "organization": {
      "name": "Acme Support",
      "slug": "acme-support",
      "plan": "growth"
    },
    "owner": {
      "email": "owner@acme.test",
      "full_name": "Owner Admin"
    }
  }'
```

Response excerpt:

```json
{
  "organization": {
    "id": 1,
    "slug": "acme-support",
    "plan": "growth"
  },
  "owner": {
    "id": 1,
    "role": "owner",
    "api_token": "sn_owner_..."
  }
}
```

## Create a membership

```bash
curl -X POST http://localhost:3000/v1/memberships \
  -H "Authorization: Bearer sn_owner_..." \
  -H "Content-Type: application/json" \
  -d '{
    "membership": {
      "email": "agent@acme.test",
      "full_name": "Agent Smith",
      "role": "agent"
    }
  }'
```

## Create a ticket

```bash
curl -X POST http://localhost:3000/v1/tickets \
  -H "Authorization: Bearer sn_member_..." \
  -H "Content-Type: application/json" \
  -d '{
    "ticket": {
      "subject": "Billing portal shows 500",
      "description": "Customer hits a 500 after checkout confirmation.",
      "requester_name": "Jamie Customer",
      "requester_email": "jamie@example.com",
      "inbox": "billing",
      "priority": "urgent"
    }
  }'
```

## Validation failure example

```json
{
  "error": {
    "code": "validation_failed",
    "message": "Email is invalid",
    "details": {
      "email": [
        "Email is invalid"
      ]
    },
    "request_id": "4a1d31eb-7d4d-48e0-95ff-bc1a0d1c2f38",
    "correlation_id": "f894aa1e-662a-4f6c-9d5f-fc7af4a8a79f"
  }
}
```

## Authorization failure example

```json
{
  "error": {
    "code": "forbidden",
    "message": "viewer cannot perform tickets_create.",
    "request_id": "8fd87843-7da0-4813-8bde-6324045d52e7",
    "correlation_id": "0dfca4e0-55c2-4606-bab9-4f51d68b31ee"
  }
}
```

## Tenant-isolation failure example

```json
{
  "error": {
    "code": "not_found",
    "message": "The requested resource was not found.",
    "request_id": "58fe47d8-e6af-4214-9f76-f7a29f8d805a",
    "correlation_id": "ec20b997-3213-47ea-8e2f-5fd3d41d9f92"
  }
}
```
