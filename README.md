# AgentForge

AgentForge is an in-progress Flutter client for reviewing pull requests on a
Tailscale-connected Forgejo instance and coordinating trusted coding-agent
endpoints.

The repository currently contains working Forgejo read/review surfaces and
useful agent/coordination prototypes. It is **not release-ready**: verified
mobile links, diff/check review, authenticated agent transport, real MCP
sessions, accessibility acceptance, and physical-device CUJs remain gated.

## Current capabilities

- Forgejo URL + PAT settings, open-PR list, detail, comments, and formal reviews
- HTTPS/custom-scheme PR deep-link parsing and platform registration
- Persistent agent endpoint registry and fresh active-work badges
- Agent context and idempotent feedback against a loopback development side-car
- Repository-centric coordination view

Formal reviews are pinned to an exact PR head, but AgentForge does not yet show
diffs or checks. Inspect those in Forgejo before approving.

## Repository

| Role | Location |
|---|---|
| Canonical | [avis-pbook Forgejo](https://avis-pbook.tail651ec3.ts.net/avidullu/agentforge) |
| Mirror | [GitHub](https://github.com/avidullu/agentforge) |

Local remotes use `origin` for Forgejo and `github` for the mirror. After a
Forgejo merge, verify both `main` heads and fast-forward the mirror explicitly
if no automated mirror job is configured.

## Quick start

Required toolchain: Flutter 3.44.6+ / Dart 3.12+.

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze --fatal-infos
flutter test --coverage
flutter run -d chrome       # or a configured Android/iOS device
```

Loopback-only development side-car:

```bash
dart run tool/mock_agent_server.dart
# Register http://127.0.0.1:8765 on the same device/machine.
# Android and iOS permit these loopback exceptions only in debug builds.
# On Android, use `adb reverse tcp:8765 tcp:8765` when the mock runs on the
# development computer.
```

Remote agent control requires authenticated HTTPS; the mock is intentionally
not a remote/tailnet server.

## Start here

- [OpenAI Build Week submission tracker](docs/projects/AF-017-OpenAI-Build-Week-Submission.md)
- [Canonical tracker](docs/08-Implementation-Plan-and-Milestones.md)
- [Mobile design handoff review](docs/10-Mobile-Design-Handoff-Review.md)
- [Agent endpoint/MCP target](docs/AGENT_MCP_CONTRACT.md)
- [Deep-link setup and open gates](docs/DEEP_LINKING.md)
- [Architecture](docs/01-Vision-and-Architecture.md)

## Privacy and license

The code repository is public; the product's runtime-data goal is private
tailnet operation. Runtime font fetching is disabled by using platform system
fonts, Android backup is disabled, and production agent endpoints must use
HTTPS. A distribution/open-source license has not yet been selected; absent a
license grant, copyright remains with the owner.
