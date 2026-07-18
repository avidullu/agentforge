# Agent endpoint contract and MCP target

**Status:** PROTOTYPE / IN PROGRESS

**Normative MCP target:** stable specification `2025-11-25`

**Current app:** a small REST side-car plus an experimental JSON-only resource
read adapter. It is **not** a complete MCP Streamable HTTP client.

This distinction is intentional. AgentForge must not claim MCP interoperability
until it implements initialization, protocol/capability negotiation,
`notifications/initialized`, session/version headers, JSON and SSE responses,
response correlation, and authenticated transport.

Primary references:

- [MCP lifecycle](https://modelcontextprotocol.io/specification/2025-11-25/basic/lifecycle)
- [MCP transports](https://modelcontextprotocol.io/specification/2025-11-25/basic/transports)
- [MCP authorization](https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization)
- [MCP tools](https://modelcontextprotocol.io/specification/2025-11-25/server/tools)

## Trust boundary

- Forgejo is the source of truth for repository state, diffs, reviews, and
  merge operations.
- An agent endpoint supplies ephemeral status, an authored rationale summary,
  recent actions, and a feedback delivery channel.
- Do not expose raw chain-of-thought. `rationale_summary` is concise,
  agent-authored user-facing context.
- A PR is `{forgeInstanceId, owner, repo, number, headSha}`.
- An endpoint is `{agentEndpointId, hostId}`; display names are not identities.
- AgentForge sends PR context only to endpoints explicitly associated with that
  PR. Selecting another endpoint is an explicit user action.

## Transport and authentication requirements

Production/remote endpoints must:

1. Use HTTPS with certificate validation. Prefer a stable tailnet DNS name and
   narrowly scoped Tailscale HTTPS proxy/Serve configuration.
2. Authenticate the client and bind the credential to the expected endpoint
   identity. Never embed credentials in the URL.
3. Support pairing, revocation, rotation, and capability/version discovery.
4. Enforce least privilege and input limits; log only redacted metadata.
5. Return typed errors without reflecting secrets or internal reasoning.

Plain HTTP is allowed only for a loopback (`127.0.0.1` or `localhost`)
development mock. Do not expose the bundled mock on a LAN or
tailnet: it has no authentication and permissive development CORS. Android and
iOS permit these exceptions only in debug builds, with loopback-only platform
network policies. Use `adb reverse tcp:8765 tcp:8765` when the mock runs on the
development computer.

## Current REST side-car (v0 development contract)

This contract exists to exercise UI and transport behavior while the secure MCP
adapter is designed. It must not be used as a remote production control plane.

### `GET /active-work`

Response is an array or `{ "items": [...] }`:

```json
[
  {
    "repo": "avidullu/agentforge",
    "pr_number": 42,
    "branch": "codex/deep-link-hardening",
    "title": "Harden deep links and review targeting",
    "status": "in_progress",
    "updated_at": "2026-07-18T12:00:00Z"
  }
]
```

Rules:

- `status` must be `active`, `in_progress`, or `working` to be shown as active.
- `updated_at` is required and must be no older than five minutes.
- Completed, missing-heartbeat, or stale items are not used as PR provenance.
- A future version will return endpoint identity, Forgejo instance ID, head SHA,
  capability/version, and a typed endpoint-health envelope.

### `GET /context?owner=&repo=&pr=`

```json
{
  "plan": "1) Repair deep links\n2) Run the device CUJ",
  "rationale_summary": "The app and app_links currently compete for the URL.",
  "recent_actions": [
    "Updated Android manifest",
    "Ran Flutter tests"
  ],
  "status": "in_progress",
  "updated_at": "2026-07-18T12:05:00Z"
}
```

Legacy `reasoning` is read for compatibility, but new endpoints must send
`rationale_summary`. Never send private hidden reasoning or secrets.

### `POST /feedback`

Request:

```json
{
  "owner": "avidullu",
  "repo": "agentforge",
  "pr": 42,
  "message": "Review the alternate-mode iOS decision",
  "client_message_id": "019f...",
  "idempotency_key": "019f..."
}
```

Accepted response:

```json
{
  "ok": true,
  "message": "queued",
  "delivery_id": "019f..."
}
```

Rules:

- `ok` must explicitly be `true`; a generic 2xx is not sufficient.
- An accepted response must include a nonempty `delivery_id`; otherwise the
  draft remains recoverable and the result is treated as noncompliant.
- The endpoint must deduplicate the idempotency key for a documented retention
  window and bind it to the request body.
- A manual retry of the same unchanged draft reuses its `client_message_id`.
- AgentForge does not retry an ambiguous write through a second transport. A
  timeout can mean the server accepted the write before the response was lost.
- The current UI reports the immediate message/delivery IDs, but persisted
  delivery state is still required before the feedback workflow is complete.

## Target delivery lifecycle

Every user message has one `clientMessageId`; every accepted endpoint delivery
has one `deliveryId` and exact destination identity.

```text
draft -> sending -> queued -> delivered -> processing -> replied
                 \-> failed (retryable | terminal)
```

Required event fields:

- `clientMessageId`, `deliveryId`, `agentEndpointId`, `hostId`
- full PR identity including `forgeInstanceId` and `headSha`
- state, sequence number, observed timestamp, error code, retryability
- optional user-facing reply/rationale summary; never chain-of-thought

Receipts are adapter-driven. Timers may animate a pending state but must never
invent delivery or mutate “the last message.”

## Target MCP surface

Names are provisional until AF-004 threat modeling and capability negotiation:

| Kind | Name / URI | Purpose |
|---|---|---|
| Tool | `agentforge.status.get` | Endpoint identity, version, capabilities, health, heartbeat |
| Tool | `agentforge.work.list` | Fresh work records with stable PR/head identity |
| Tool | `agentforge.pr.context.get` | Plan, rationale summary, recent actions for one authorized PR |
| Tool | `agentforge.feedback.send` | Idempotently enqueue feedback to one endpoint/PR |
| Resource | `agentforge://feedback/{deliveryId}` | Delivery state and optional response |

The MCP client must:

1. Initialize using the stable supported protocol version.
2. Validate advertised capabilities before any tool/resource operation.
3. Send `MCP-Protocol-Version` on subsequent HTTP requests and manage an
   optional `Mcp-Session-Id` as specified.
4. Accept both `application/json` and `text/event-stream` responses.
5. Validate JSON-RPC ID, error/result shape, tool `isError`, content types, size
   limits, and pagination cursors.
6. Terminate/reconnect sessions deliberately and never replay ambiguous
   mutations without idempotency semantics.

## Development mock

```bash
dart run tool/mock_agent_server.dart
# loopback only: http://127.0.0.1:8765
```

The mock is reachable only from the same machine/device. A phone cannot reach
the computer's loopback listener via its Tailscale IP. Use an authenticated
HTTPS proxy and a real wrapper for remote-device verification.

## Open gates

- Endpoint pairing/authentication and credential storage.
- Stable instance/endpoint/PR identity fields in every call.
- Typed partial-failure and heartbeat state in the app.
- Standards-compliant MCP session, SSE, authorization, and conformance tests.
- Persistent delivery receipts/subscriptions and correlated replies.
- Real Codex/Claude wrapper and Android/iOS device acceptance.
