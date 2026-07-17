# AgentForge

Personal Flutter app for reviewing PRs on a Tailscale-connected Forgejo instance and coordinating local coding agents (Claude, Codex, Gemini, Grok, …) via a small MCP/HTTP side-car contract.

## Features (Milestones 0–5)

- Deep link Forgejo PR URLs (App Links + `agentforge://` scheme)
- Connect to Forgejo (URL + PAT) — list open PRs, detail, comments, Approve / Request changes
- Agent registry with optional MCP base URLs
- Active-work badges and **Coordination** view (work by repository)
- **Agent context** on PR detail: plan, reasoning, recent actions, send feedback

## Repository

| Canonical | [avis-pbook Forgejo](https://avis-pbook.tail651ec3.ts.net/avidullu/agentforge) |
| Mirror | [GitHub](https://github.com/avidullu/agentforge) |

## Quick start

```bash
flutter pub get
flutter test
flutter run -d chrome   # or a device
```

Mock agent for local demos:

```bash
dart run tool/mock_agent_server.dart
# Register agent MCP URL http://127.0.0.1:8765
```

See [`docs/AGENT_MCP_CONTRACT.md`](./docs/AGENT_MCP_CONTRACT.md), [`docs/DEEP_LINKING.md`](./docs/DEEP_LINKING.md), [`HANDOFF.md`](./HANDOFF.md).

## License

Private — All rights reserved.
