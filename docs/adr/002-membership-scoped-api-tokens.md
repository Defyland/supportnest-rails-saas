# ADR 002: Authenticate with membership-scoped bearer API tokens

## Status

Accepted

## Context

This slice needs role-aware tenant authentication without implementing a full human identity provider, password reset flow, or session lifecycle.

## Decision

Each membership receives a bearer API token at creation time. Only the SHA-256 digest is stored. The token scopes the caller to exactly one organization and one role.

## Consequences

- tenant resolution is trivial and safe
- RBAC checks can run directly from the authenticated membership
- raw tokens are never persisted after issuance
- token rotation and revocation are easy follow-up features
- SSO and end-user identity remain out of scope for this slice
