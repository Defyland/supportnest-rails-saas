# Authorization Matrix

## Roles

- `owner`: full tenant administration
- `admin`: tenant administration without bootstrap-only ownership semantics
- `agent`: daily ticket operations
- `viewer`: read-only support visibility

## Permissions

| Permission | Owner | Admin | Agent | Viewer |
| --- | --- | --- | --- | --- |
| `organizations_read` | Yes | Yes | Yes | Yes |
| `memberships_list` | Yes | Yes | Yes | Yes |
| `memberships_create` | Yes | Yes | No | No |
| `memberships_update` | Yes | Yes | No | No |
| `tickets_list` | Yes | Yes | Yes | Yes |
| `tickets_read` | Yes | Yes | Yes | Yes |
| `tickets_create` | Yes | Yes | Yes | No |
| `tickets_update` | Yes | Yes | Yes | No |

## Additional invariants

- the `owner` role cannot be created through the public membership create endpoint
- only an existing owner can assign the `owner` role to another membership
- a membership cannot suspend itself
- all resource lookups remain tenant-scoped even when the role allows the action

## Code references

- permission map: `app/services/security/authorizer.rb`
- controller enforcement: `app/controllers/application_controller.rb`
- membership mutation safeguards: `app/services/memberships/update.rb`
