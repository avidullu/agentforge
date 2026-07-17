# AgentForge — Handoff Document

**Last updated**: 2026-07-18  
**Current owner of work**: Ready for next coding-agent session (Grok Build / Claude / Codex)

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
| **Local checkout (this machine)** | `/home/avidullu/projects/Agent/agentforge` |
| **Default branch** | `main` |

### Git remotes (local)

```
origin   forge:avidullu/agentforge.git          # push here first
github   https://github.com/avidullu/agentforge.git
```

Pattern matches other Forgejo-primary repos (e.g. `Khelsutra/badminton-highlight-indexer`):  
`git push origin`, optional `git push github` to keep the mirror warm.

**Onboarded to avis-pbook**: 2026-07-18 (full history on `main` @ `d5e59fd`).

---

## 3. Current Status (as of this handoff)

### Completed
- Project scaffolding (Dart package + Riverpod + go_router routes)
- Dark Material 3 theme
- Basic screens: Home, Settings, PR Detail (receives deep-link path params)
- Router supports path shapes:
  - `/:owner/:repo/pulls/:number`
  - `/:owner/:repo/pull/:number`
- GitHub Actions CI (`flutter analyze` + `flutter test`) — still GitHub-hosted; Forgejo Actions not configured yet
- Core design docs in `docs/`
- Deep linking guide in `docs/DEEP_LINKING.md`
- **Forgejo onboarding** (private repo under `avidullu/`, local clone, dual remotes)

### Gaps blocking a real-device Milestone 0 demo
- **No `android/` or `ios/` platform trees** — this is Dart-only scaffolding; need `flutter create .` (or equivalent) to generate platform projects
- **Platform deep-link config** not applied (AndroidManifest intent-filter, iOS Associated Domains, `assetlinks.json` / AASA for `avis-pbook.tail651ec3.ts.net`)
- **`app_links` is a dependency but not wired** in `main.dart` / router — incoming OS links are not yet handed to `go_router`
- **Flutter SDK not installed** on this WSL host (`flutter: command not found`) — device/emulator work likely on Windows host or after installing Flutter here
- Real device CUJ (Gmail → App → PR Detail) not run yet

### Milestone status
- **Milestone 0** (Skeleton + Deep Link Ready): ~60–70% (UI/router skeleton yes; platform + live deep link no)
- **Milestone 1** (Forgejo connection + real PR list): Not started
- **Milestones 2–5**: Not started

---

## 4. Immediate Priority (what to do next)

**Goal of the next session**: Finish Milestone 0 so a real Forgejo PR link from Gmail opens AgentForge on the correct PR detail screen.

### Ordered plan

1. **Dev environment**
   - Install Flutter stable (WSL and/or Windows), Android SDK / Xcode as needed
   - Confirm `flutter doctor` clean enough for a device or emulator

2. **Generate platform projects**
   - From repo root: `flutter create . --project-name agentforge --org com.avidullu` (adjust org if preferred)
   - Commit generated `android/`, `ios/`, and any other platform dirs you want to keep

3. **Wire deep links end-to-end**
   - Android: intent-filter for `https://avis-pbook.tail651ec3.ts.net` (see `docs/DEEP_LINKING.md`)
   - iOS: Associated Domains + Info.plist
   - Host (or document how to host) `assetlinks.json` / AASA for App Links / Universal Links verification
   - Wire `app_links` → `GoRouter` so cold-start and warm-start both land on PR Detail

4. **On-device CUJ**
   - Build/install on a real phone
   - Email yourself a real PR URL from avis-pbook (e.g. a Khelsutra indexer PR)
   - Tap → app opens → owner/repo/number match

5. **Close the loop**
   - Mark Milestone 0 complete in README + this HANDOFF
   - Push to `origin` (Forgejo); optionally mirror to `github`
   - Start **Milestone 1**: Settings (instance URL + PAT) + live open-PR list via Forgejo API

### After Milestone 0 (near-term roadmap)

| Milestone | Outcome |
|-----------|---------|
| **1** | Connect to avis-pbook; list open PRs over Tailscale |
| **2** | PR detail: conversation, comment, Approve / Request Changes |
| **3** | Agent registry + status + “who is working on what” |
| **4** | Agent context panel via MCP (plan, reasoning, send feedback) |
| **5** | Polish + multi-machine coordination view |

Details: `docs/08-Implementation-Plan-and-Milestones.md`, `docs/09-Multi-Agent-Coordination.md`.

### Optional infra (can wait)

- Re-home CI to Forgejo Actions on avis-pbook (self-hosted runner already present: `avis-msi-wsl-runner`) so GitHub Actions is not required
- Topics / description already set on Forgejo; enable branch protection later if desired

---

## 5. How to run (once Flutter is available)

```bash
git clone forge:avidullu/agentforge.git
cd agentforge
flutter pub get
flutter run
```

Local path on avis-msi WSL: `/home/avidullu/projects/Agent/agentforge`

---

## 6. Coding Standards

- Prefer clear, readable code over cleverness
- Feature-first folders under `lib/features/`
- Shared widgets/utilities in `lib/shared/` and `lib/core/`
- Riverpod for state
- Small, focused commits
- Keep `docs/` current
- Tests for non-trivial logic

---

## 7. Key Design Documents

| File | Content |
|------|--------|
| `docs/01-Vision-and-Architecture.md` | Overall vision |
| `docs/08-Implementation-Plan-and-Milestones.md` | Milestone plan + CUJs |
| `docs/09-Multi-Agent-Coordination.md` | Multi-machine / multi-agent requirements |
| `docs/DEEP_LINKING.md` | Gmail deep-link finish guide |
| `HANDOFF.md` | This file |

Additional design docs may still live in Google Drive: **“AgentForge Mobile App - Design Docs”**.

---

## 8. Suggested First Prompt for the Next Session

> Continue from `HANDOFF.md` in agentforge (`/home/avidullu/projects/Agent/agentforge`, origin = Forgejo on avis-pbook).  
> Finish Milestone 0: generate Android/iOS platform projects, wire `app_links` into go_router, and add platform deep-link config for `avis-pbook.tail651ec3.ts.net` so a Gmail PR link opens the correct PR Detail screen.  
> Commit and push to `origin` (Forgejo). Update HANDOFF + README when Milestone 0 is done.

---

## 9. Success Criteria for the next handoff

The next AI session is successful when:

- [ ] `android/` (and `ios/` if targeting iPhone) exist and the app builds
- [ ] A real PR link from Gmail (or `adb`/Safari test URL) opens AgentForge on the correct PR Detail screen
- [ ] Changes committed and pushed to Forgejo `main`
- [ ] This HANDOFF + README reflect Milestone 0 complete and point at Milestone 1
