# Error Format

All API failures return a standardized envelope:

```json
{
  "error": {
    "code": "validation_failed",
    "message": "Human-readable summary",
    "details": {
      "field": [
        "Detailed validation error"
      ]
    },
    "request_id": "5c1ef88f-f8cc-46d8-8e66-9a3f10d0f4ef",
    "correlation_id": "b45cf70f-9984-45dd-8d28-dc786d3524f0"
  }
}
```

## Codes

- `missing_parameter`: required JSON envelope is missing
- `invalid_parameter`: query parameter is malformed or outside its allowed range
- `unauthorized`: bearer token missing or invalid
- `forbidden`: token is valid but role lacks permission
- `not_found`: tenant-scoped resource not found
- `conflict`: uniqueness or other write conflict
- `precondition_required`: required conditional update header is missing
- `precondition_failed`: conditional update header is malformed
- `validation_failed`: model or quota validation failed
- `rate_limited`: per-minute request quota exceeded

## Notes

- `request_id` maps to the Rails request lifecycle and log correlation.
- `correlation_id` propagates cross-service intent and is stored on outbound events.
- `details` is omitted when the error has no field-level payload.
