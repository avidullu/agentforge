# AgentForge — Handoff Document

**Last updated**: 2026-07-18  
**HEAD (approx)**: Milestone 0–3 code on `main` (Forgejo + GitHub)

---

## 1. Project Goal

Personal Flutter app to review Forgejo PRs (deep-linked from Gmail) and coordinate local coding agents over Tailscale via MCP.

---

## 2. Repository

| | |
|--|--|
| Canonical | https://avis-pbook.tail651ec3.ts.net/avidullu/agentforge |
| SSH | `forge:avidullu/agentforge.git` |
| GitHub | https://github.com/avidullu/agentforge |
| Local | `/home/avidullu/projects/Agent/agentforge` |
| Flutter | `~/flutter` (+ `~/bin` on PATH) |

---

## 3. Status

| Milestone | Status |
|-----------|--------|
| **0** Deep linking | Code complete — device Gmail HTTPS CUJ needs well-known + phone |
| **1** Forgejo + PR list | Code complete |
| **2** Comments + reviews | Code complete (Comment / Approve / Request changes) |
| **3** Agent registry | Code complete — register agents, optional `/active-work` poll, PR chips |
| **4** MCP context panel | **Next** — Streamable HTTP MCP client, plan/reasoning/feedback |
| **5** Polish + multi-machine view | Planned |

**Verified**: `flutter analyze` clean; **20** tests passing; live list/whoami against avis-pbook API.

---

## 4. What to do next

### Highest leverage for you (human)

1. Install Android SDK (or open the project on Windows) → `flutter run`
2. Settings → PAT from Forgejo → Test → Save → browse open PRs
3. Optional: host `docs/well-known/*` on avis-pbook for verified App Links

### Next agent work (Milestone 4)

1. Real MCP client (Streamable HTTP) against registered agent base URLs
2. PR detail panel: live plan, recent tools/reasoning, send feedback
3. Harden active-work discovery beyond `GET …/active-work`

---

## 5. Run

```bash
export PATH="$HOME/bin:$HOME/flutter/bin:$PATH"
cd /home/avidullu/projects/Agent/agentforge
flutter pub get && flutter test
flutter run
```

---

## 6. Code map

| Path | Role |
|------|------|
| `lib/core/deep_links/` | Deep link parse + warm listener |
| `lib/core/settings/` | Forgejo URL + PAT |
| `lib/core/forgejo/` | API client + PR/review models |
| `lib/core/agents/` | Registry + active-work client |
| `lib/features/home/` | Open PR list + agent chips |
| `lib/features/pr_detail/` | Detail, comments, review actions |
| `lib/features/agents/` | Agent CRUD UI |
| `lib/features/settings/` | Connection form |
| `docs/DEEP_LINKING.md` | App Links ops |

---

## 7. Suggested next prompt

> Continue AgentForge Milestone 4: MCP Streamable HTTP client for registered agents, show plan/reasoning on PR detail, and a feedback send path. Tests + push to Forgejo origin.
