# Multi-agent and multi-machine coordination

**Status:** UI prototype implemented; durable coordination semantics open.

## Goal

Show fresh, attributable work per trusted endpoint and relate work on the same
Forgejo repository without mistaking self-reported activity for Git truth.

## Identity and source of truth

- Forgejo/Git is authoritative for repository, branch, PR, and head state.
- Endpoint records use stable `agentEndpointId` and `hostId`; display names are
  presentation only.
- PR records use `forgeInstanceId`, owner, repo, number, and head SHA.
- Self-reported work is presence/context, not proof of authorship.
- Durable provenance should use a Forgejo-backed marker or another auditable
  record bound to the authenticated endpoint and exact head.

## Freshness and health

An active-work item must include `status` and `updated_at`. The prototype admits
only active/working/in-progress records no older than five minutes.

The complete UI must preserve per-endpoint states:

- loading
- online/idle
- online/working
- stale
- unreachable/offline
- authentication or protocol failure
- malformed response
- partial failure while other endpoints remain usable

An error is never “no active work.” Retain last-known data with a stale label,
timestamp, and retry where safe.

## Required views

- Home: PR badges for fresh, explicitly associated endpoints.
- Endpoint registry: identity, host, trust/pairing, capability, health, last
  heartbeat, current work, and revoke/edit/test actions.
- Coordination: repository groups with exact branches/heads, conflicts or
  overlaps, and partial-failure visibility.
- PR detail: claimed/linked endpoints only, with explicit destination before
  sharing context or sending feedback.

## Transport

See [`AGENT_MCP_CONTRACT.md`](AGENT_MCP_CONTRACT.md). Remote endpoints require
authenticated HTTPS. The loopback mock is a local UI-development aid only.
