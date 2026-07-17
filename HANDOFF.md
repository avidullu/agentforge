# AgentForge — Handoff Document

**Last updated**: 2026-07-18  
**Current owner of work**: Ready for Grok Build (or any coding agent) on the local machine

---

## 1. Project Goal (one sentence)

Build a personal Flutter app that lets me review Forgejo PRs (deep-linked from Gmail) and coordinate local coding agents (Claude / Codex / Gemini / Grok etc.) running on multiple machines over Tailscale via MCP.

---

## 2. Repository

- **GitHub**: https://github.com/avidullu/agentforge  
  (Currently private — user may make it public)
- **Default branch**: `main`

---

## 3. Current Status (as of this handoff)

### Completed
- Project scaffolding (Flutter + Riverpod + go_router)
- Dark Material 3 theme
- Basic screens: Home, Settings, PR Detail (receives deep-link params)
- Router supports deep links of the form:
  - `/:owner/:repo/pulls/:number`
  - `/:owner/:repo/pull/:number`
- GitHub Actions CI (`flutter analyze` + `flutter test`)
- Core design documentation in `docs/`
- Deep linking guide in `docs/DEEP_LINKING.md`

### Not yet done (Milestone 0 remaining work)
- Platform-specific deep link configuration (AndroidManifest intent-filter + iOS Associated Domains)
- Real device testing of the Gmail → App deep link CUJ

### Milestone status
- **Milestone 0** (Skeleton + Deep Link): ~80% complete  
- **Milestone 1** (Forgejo connection + real PR list): Not started

---

## 4. Immediate Priority (what to do next)

**Goal of the next session**: Make the Gmail → App deep-link demo work on a real phone.

Concrete tasks:
1. Add the Android intent-filter (and `assetlinks.json` instructions).
2. Add the iOS Associated Domains + Info.plist entries.
3. Document the exact steps to test with a real Forgejo PR link from Gmail.
4. Once the deep link works end-to-end → mark Milestone 0 complete and start Milestone 1.

---

## 5. How to run the current code

```bash
git clone git@github.com:avidullu/agentforge.git
cd agentforge
flutter pub get
flutter run
```

---

## 6. Coding Standards to Follow

Taken from the owner’s existing repos (especially `khelsutra`):

- Prefer clear, readable code over cleverness
- Feature-first folder structure under `lib/features/`
- Keep shared widgets and utilities in `lib/shared/` and `lib/core/`
- Use Riverpod for state
- Write small, focused commits
- Keep documentation in the `docs/` folder up to date
- Add tests for non-trivial logic

---

## 7. Key Design Documents (already in repo)

| File | Content |
|------|--------|
| `docs/01-Vision-and-Architecture.md` | Overall vision |
| `docs/08-Implementation-Plan-and-Milestones.md` | Milestone plan + CUJs |
| `docs/09-Multi-Agent-Coordination.md` | Multi-machine / multi-agent requirements |
| `docs/DEEP_LINKING.md` | How to finish the Gmail deep-link demo |
| `HANDOFF.md` | This file |

Additional design docs still live in Google Drive under the folder  
**“AgentForge Mobile App - Design Docs”** if needed for reference.

---

## 8. Suggested First Prompt for Grok Build

You can paste something like this:

> Continue from the HANDOFF.md in the agentforge repo.  
> Finish Milestone 0 by adding the platform deep-link configuration (Android + iOS) so that tapping a Forgejo PR link in Gmail opens the app on the correct PR detail screen.  
> Then update the documentation and mark Milestone 0 as complete.

---

## 9. Success Criteria for this handoff

The next AI session is successful when:

- A real PR link opened from Gmail launches the AgentForge app and lands on the correct PR Detail screen.
- The change is committed and pushed to `main`.
- `HANDOFF.md` is updated to reflect the new status.
