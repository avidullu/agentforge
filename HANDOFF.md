# AgentForge — Handoff Document

**Last updated**: 2026-07-18  
**Current owner of work**: Ready for Milestone 2 (formal reviews) or device install

---

## 1. Project Goal (one sentence)

Build a personal Flutter app that lets me review Forgejo PRs (deep-linked from Gmail) and coordinate local coding agents (Claude / Codex / Gemini / Grok etc.) running on multiple machines over Tailscale via MCP.

---

## 2. Repository

| Role | Location |
|------|----------|
| **Canonical** | https://avis-pbook.tail651ec3.ts.net/avidullu/agentforge |
| **SSH** | `forge:avidullu/agentforge.git` |
| **GitHub mirror** | https://github.com/avidullu/agentforge |
| **Local** | `/home/avidullu/projects/Agent/agentforge` |

```
origin → forge:avidullu/agentforge.git
github → https://github.com/avidullu/agentforge.git
```

Flutter on this WSL host: `~/flutter` (+ `~/bin` on PATH for the unzip shim).

---

## 3. Current Status

| Milestone | Status |
|-----------|--------|
| **0** Skeleton + deep linking | **Code complete** — phone Gmail HTTPS CUJ still needs well-known hosting + device |
| **1** Forgejo connection + PR list | **Code complete** — Settings (URL+PAT), open PR list, PR detail title/body |
| **2** Conversation + formal reviews | **Next** |
| **3–5** Agents / MCP / polish | Planned |

### Verified on this machine

- `flutter analyze` clean
- Unit/widget tests green (16+)
- Live API smoke against avis-pbook: `whoAmI=avidullu`, open PRs list works with token in `~/.config/forgejo/avis-pbook.token` (do **not** commit the token)

### App usage

1. `flutter run` on a device/emulator (Android SDK not installed on this WSL yet)
2. Settings → paste PAT → Test connection → Save
3. Home shows open PRs; tap opens detail with title + description
4. Deep links: `agentforge://pr/owner/repo/N` or HTTPS after verification

---

## 4. Immediate Priority (Milestone 2)

1. Load PR timeline / comments (`/api/v1/repos/{o}/{r}/issues/{n}/comments` + review comments)
2. Post a comment
3. Approve / Request changes via Forgejo review API
4. Keep review UI dense and dark; agent badges later (M3)

Optional ops (can parallel):

- Host `docs/well-known/assetlinks.json` + AASA on avis-pbook
- Install Android SDK / run on phone from Windows host

---

## 5. How to run

```bash
export PATH="$HOME/bin:$HOME/flutter/bin:$PATH"
cd /home/avidullu/projects/Agent/agentforge
flutter pub get && flutter test
flutter run
```

---

## 6. Key code map

| Path | Role |
|------|------|
| `lib/core/deep_links/` | URI → go_router location + warm listener |
| `lib/core/settings/` | Secure storage for URL + PAT |
| `lib/core/forgejo/` | dio client, models, providers |
| `lib/features/home/` | Open PR list |
| `lib/features/settings/` | Connection form |
| `lib/features/pr_detail/` | Title + body (reviews next) |
| `docs/DEEP_LINKING.md` | App Links / AASA ops |

---

## 7. Suggested next prompt

> Continue AgentForge Milestone 2: load PR conversation/comments from Forgejo, post comments, and Approve / Request Changes. Tests + push to `origin` (Forgejo).

---

## 8. Success criteria

- [x] M0 platform + deep-link wiring committed
- [x] M1 Settings + open PR list + detail body against avis-pbook API
- [ ] Device install + optional Gmail HTTPS CUJ
- [ ] M2 formal review actions
