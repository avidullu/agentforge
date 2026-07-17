# Agent side-car HTTP / MCP contract

AgentForge talks to **local agents over Tailscale** using a small HTTP contract (preferred) plus optional MCP JSON-RPC.

Base URL is configured per agent in the app (e.g. `http://100.x.y.z:8765`).

## Required (for badges + coordination)

### `GET /active-work`

Response: JSON array (or `{ "items": [ ... ] }`):

```json
[
  {
    "repo": "Khelsutra/badminton-highlight-indexer",
    "pr_number": 623,
    "branch": "docs/golden-eval",
    "title": "docs: golden eval report",
    "status": "in_progress",
    "updated_at": "2026-07-18T12:00:00Z"
  }
]
```

## Milestone 4 context panel

### `GET /context?owner=&repo=&pr=`

```json
{
  "plan": "1) Finish tests\n2) Open review",
  "reasoning": "Coverage gap on marker polling…",
  "recent_actions": [
    "Edited deploy/worker.sh",
    "Ran pytest -q"
  ],
  "status": "in_progress",
  "updated_at": "2026-07-18T12:05:00Z"
}
```

### `POST /feedback`

```json
{
  "owner": "Khelsutra",
  "repo": "badminton-highlight-indexer",
  "pr": 623,
  "message": "Prefer option B; skip the docs refactor"
}
```

Response: `{ "ok": true, "message": "queued" }`

## Optional MCP JSON-RPC

`POST {base}/mcp` with body:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "resources/read",
  "params": { "uri": "agentforge://context/{owner}/{repo}/{pr}" }
}
```

```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tools/call",
  "params": {
    "name": "send_feedback",
    "arguments": {
      "owner": "…",
      "repo": "…",
      "pr": 1,
      "message": "…"
    }
  }
}
```

## Local mock server

```bash
dart run tool/mock_agent_server.dart
# listens on http://127.0.0.1:8765
```

Register an agent in the app with MCP base URL `http://127.0.0.1:8765` (or your Tailscale IP).
