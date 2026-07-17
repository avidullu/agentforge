# AgentForge — Handoff Document

**Last updated**: 2026-07-18  
**Current owner of work**: Next session continues Milestone 1 (or device-verify M0 CUJ)

---

## 1. Project Goal (one sentence)

Build a personal Flutter app that lets me review Forgejo PRs (deep-linked from Gmail) and coordinate local coding agents (Claude / Codex / Gemini / Grok etc.) running on multiple machines over Tailscale via MCP.

---

## 2. Repository (canonical + remotes)

| Role | Location |
|------|----------|
| **Canonical (Forgejo / avis-pbook)** | https://avis-pbook.tail651ec3.ts.net/avidullu/agentforge |
| **SSH clone** | `forge:avidullu/agentforge.git` |
| **GitHub (secondary mirror)** | https://github.com/avidullu/agentforge |
| **Local checkout** | `/home/avidullu/projects/Agent/agentforge` |
| **Default branch** | `main` |

```
origin   forge:avidullu/agentforge.git
github   https://github.com/avidullu/agentforge.git
```

Flutter SDK on this WSL host: `~/flutter` (add `~/flutter/bin` and `~/bin` to `PATH`; `~/bin/unzip` is a Python shim used to bootstrap Flutter without apt).

---

## 3. Current Status

### Milestone 0 — Skeleton + Deep Link Ready: **code complete** (device CUJ pending)

- Flutter project with `android/` + `ios/` (`com.avidullu.agentforge`)
- Dark Material 3 theme, Home / Settings / PR Detail
- `go_router` PR routes + **`app_links` cold + warm start**
- Android App Links intent-filters for `avis-pbook.tail651ec3.ts.net` + `agentforge://` custom scheme
- iOS `CFBundleURLTypes` + Associated Domains entitlement
- Unit + widget tests green (`flutter analyze` clean, **10 tests passed**)
- Hosting templates: `docs/well-known/assetlinks.json`, `apple-app-site-association`

### Still needed for a fully verified Gmail → App HTTPS CUJ

- Host `/.well-known/assetlinks.json` (with real SHA-256) and AASA on avis-pbook
- Run on a real phone; tap a PR link from Gmail
- Until then, custom scheme works for dev: `agentforge://pr/owner/repo/42`

### Milestone 1 — Forgejo Connection + PR List: **next**

Not started (or in progress in the next commits).

---

## 4. Immediate Priority

1. **Optional but valuable**: install Android SDK / open project on Windows host, `flutter run`, adb custom-scheme test.
2. **Milestone 1**:
   - Settings: Forgejo base URL (default `https://avis-pbook.tail651ec3.ts.net`) + PAT → `flutter_secure_storage`
   - Thin Forgejo API client (`dio`): list open PRs (user + orgs)
   - Home screen: real PR list; tap → existing PR Detail route
3. Then Milestone 2: conversation + formal review actions.

---

## 5. How to run

```bash
export PATH="$HOME/bin:$HOME/flutter/bin:$PATH"
cd /home/avidullu/projects/Agent/agentforge
flutter pub get
flutter test
flutter run   # needs device/emulator + Android/iOS toolchain
```

Custom-scheme Android smoke (device connected):

```bash
adb shell am start -a android.intent.action.VIEW \
  -d "agentforge://pr/Khelsutra/badminton-highlight-indexer/611"
```

---

## 6. Coding Standards

- Clear code over cleverness; feature folders under `lib/features/`
- Shared code in `lib/core/` (and later `lib/shared/`)
- Riverpod for state; small focused commits; keep `docs/` current
- Tests for non-trivial logic (see `test/deep_link_test.dart`)

---

## 7. Key Design Documents

| File | Content |
|------|--------|
| `docs/01-Vision-and-Architecture.md` | Vision |
| `docs/08-Implementation-Plan-and-Milestones.md` | Milestones + CUJs |
| `docs/09-Multi-Agent-Coordination.md` | Multi-agent |
| `docs/DEEP_LINKING.md` | Deep-link ops + verification |
| `HANDOFF.md` | This file |

---

## 8. Suggested Next Prompt

> Continue AgentForge Milestone 1: Settings for Forgejo URL + PAT (secure storage), dio client against avis-pbook, and a real open-PR list on Home that navigates to PR Detail. Push to `origin` (Forgejo).

---

## 9. Success criteria (rolling)

- [x] Platforms generated; deep-link parsing + platform config committed
- [x] `flutter analyze` + tests green
- [ ] Real-device Gmail HTTPS CUJ (ops: well-known files + phone)
- [ ] Milestone 1: authenticated PR list from avis-pbook
