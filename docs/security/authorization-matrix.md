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
| `memberships_rotate_token` | Yes | Yes | No | No |
| `memberships_revoke_token` | Yes | Yes | No | No |
| `tickets_list` | Yes | Yes | Yes | Yes |
| `tickets_read` | Yes | Yes | Yes | Yes |
| `tickets_create` | Yes | Yes | Yes | No |
| `tickets_update` | Yes | Yes | Yes | No |

## Additional invariants

- the `owner` role cannot be created through the public membership create endpoint
- only an existing owner can assign the `owner` role to another membership
- non-owner actors cannot update, rotate, or revoke owner memberships
- every organization must retain at least one active owner with a non-expired, non-revoked token
- a membership cannot suspend itself
- all resource lookups remain tenant-scoped even when the role allows the action

## Code references

- permission source of truth: `config/authorization_matrix.yml`
- permission loader/enforcement: `app/services/security/authorizer.rb`
- controller enforcement: `app/controllers/application_controller.rb`
- membership mutation safeguards: `app/services/memberships/update.rb`
- drift guard: `test/services/security_authorizer_test.rb`
