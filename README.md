# AgentForge

Personal Flutter mobile app for reviewing PRs on a Tailscale-connected Forgejo instance and coordinating local coding agents (Claude, Codex, Gemini, Grok, etc.) via the Model Context Protocol (MCP).

## Goals

- Deep-link from Gmail → open the exact PR in the app
- Clearly identify which local agent / machine produced a PR
- Rich agent context (plan, reasoning, feedback) next to the formal PR review
- Easy visibility of active work across multiple machines on the same repository

## Status

**Milestone 0** — Project scaffolding + deep linking foundation (in progress).  
See [`HANDOFF.md`](./HANDOFF.md) for current gaps and the next-session plan.

## Repository

| | |
|--|--|
| **Canonical** | [avis-pbook Forgejo](https://avis-pbook.tail651ec3.ts.net/avidullu/agentforge) (`forge:avidullu/agentforge.git`) |
| **Mirror** | [GitHub](https://github.com/avidullu/agentforge) |

## Documentation

All design and implementation docs live in the [`docs/`](./docs/) folder.

## Quick Start (once Flutter is installed)

```bash
git clone forge:avidullu/agentforge.git
cd agentforge
flutter pub get
flutter run
```

## License

Private — All rights reserved.
