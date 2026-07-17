# AgentForge

Personal Flutter mobile app for reviewing PRs on a Tailscale-connected Forgejo instance and coordinating local coding agents (Claude, Codex, Gemini, Grok, etc.) via the Model Context Protocol (MCP).

## Goals

- Deep-link from Gmail → open the exact PR in the app
- Clearly identify which local agent / machine produced a PR
- Rich agent context (plan, reasoning, feedback) next to the formal PR review
- Easy visibility of active work across multiple machines on the same repository

## Status

| Milestone | Status |
|-----------|--------|
| **0** Skeleton + deep linking | Code complete — device Gmail CUJ pending domain verification |
| **1** Forgejo connection + PR list | Code complete — Settings, open PR list, PR title/body |
| **2** Conversation + formal reviews | Code complete — comments, Approve / Request changes |
| **3** Agent registry + status | Code complete — registry UI, active-work poll, PR chips |
| **4** MCP context panel | Next |
| **5** Polish | Planned — see `docs/08-Implementation-Plan-and-Milestones.md` |

Session state: [`HANDOFF.md`](./HANDOFF.md). Deep-link ops: [`docs/DEEP_LINKING.md`](./docs/DEEP_LINKING.md).

## Repository

| | |
|--|--|
| **Canonical** | [avis-pbook Forgejo](https://avis-pbook.tail651ec3.ts.net/avidullu/agentforge) (`forge:avidullu/agentforge.git`) |
| **Mirror** | [GitHub](https://github.com/avidullu/agentforge) |

## Quick Start

```bash
export PATH="$HOME/bin:$HOME/flutter/bin:$PATH"   # WSL layout
git clone forge:avidullu/agentforge.git && cd agentforge
flutter pub get
flutter test
flutter run
```

Debug deep link (Android):

```bash
adb shell am start -a android.intent.action.VIEW \
  -d "agentforge://pr/owner/repo/42"
```

## License

Private — All rights reserved.
