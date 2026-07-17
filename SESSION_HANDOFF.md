# AgentForge — Session Handoff

**Date**: 2026-07-18  
**Canonical repo**: https://avis-pbook.tail651ec3.ts.net/avidullu/agentforge  
**GitHub mirror**: https://github.com/avidullu/agentforge  
**Default branch**: `main`

---

## 1. What this project is

Personal **Flutter** app to:

1. Review PRs on **Forgejo** (`https://avis-pbook.tail651ec3.ts.net`) over Tailscale  
2. Deep-link from Gmail / browser into a PR  
3. Coordinate **local coding agents** (Claude / Codex / Gemini / Grok) via a small HTTP/MCP side-car  

---

## 2. Where the code lives

| Location | Path |
|----------|------|
| WSL (primary edit) | `/home/avidullu/projects/Agent/agentforge` |
| Windows demo clone | `C:\Users\avidu\Projects\agentforge` |
| Flutter (Windows) | `C:\Users\avidu\flutter` |
| Flutter (WSL) | `~/flutter` (+ `~/bin` for unzip shim) |
| PAT file (not in git) | `/home/avidullu/agentforge.pat` |
| Older forge token | `~/.config/forgejo/avis-pbook.token` |

**Remotes**

```
origin  → forge:avidullu/agentforge.git     # canonical
github  → https://github.com/avidullu/agentforge.git
```

---

## 3. Milestone status (product)

| M | Scope | Status |
|---|--------|--------|
| 0 | Skeleton + deep links | **Done** |
| 1 | Forgejo settings + PR list + detail | **Done** |
| 2 | Comments + Approve / Request changes | **Done** |
| 3 | Agent registry + active-work badges | **Done** (storage fix pending this handoff commit) |
| 4 | Agent context panel (plan/reasoning/feedback) | **Done** |
| 5 | Coordination view + home filters | **Done** |

---

## 4. Bug found this session: “Add agent” broken (Chrome web)

### Root cause

Agent registry was stored with **`flutter_secure_storage`**. That package is fine for **mobile** Keystore/Keychain, but on **Flutter web** writes often fail or behave poorly. Failures were **silent** (no snackbar), and empty Name/Machine also **returned without feedback**.

PAT/settings used the same plugin but shorter keys; agent JSON writes failed more visibly as “add does nothing.”

### Fix (this handoff)

- Agent registry → **`shared_preferences`** (reliable on web + desktop + mobile)  
- Agents UI → `ConsumerStatefulWidget`, form validation, success/error snackbars, confirm delete  
- PAT remains in **`flutter_secure_storage`** (secrets)

### How to verify

1. Hot restart / re-run Chrome app after pull  
2. Agents → **Add agent** → Name + Machine required → Save  
3. Expect snackbar “Agent … added” and list row  
4. Optional MCP URL `http://127.0.0.1:8765` with mock server  

---

## 5. How to run the demo (Windows Chrome)

```powershell
$env:Path = "C:\Users\avidu\flutter\bin;" + $env:Path
cd C:\Users\avidu\Projects\agentforge
git pull origin main
$ud = "$env:LOCALAPPDATA\agentforge-chrome-dev"
flutter run -d chrome --web-port=5173 `
  --web-browser-flag=--disable-web-security `
  --web-browser-flag=--user-data-dir=$ud
```

`--disable-web-security` is only for local demo CORS to Forgejo. Same Chrome profile keeps the saved PAT.

**PAT into clipboard (WSL):**

```bash
tr -d '\n\r' < /home/avidullu/agentforge.pat | clip.exe
```

Settings → URL `https://avis-pbook.tail651ec3.ts.net` → paste PAT → Test → **Save**.

**Mock agent (WSL):**

```bash
export PATH="$HOME/bin:$HOME/flutter/bin:$PATH"
cd /home/avidullu/projects/Agent/agentforge
dart run tool/mock_agent_server.dart   # :8765
```

---

## 6. Code map

| Path | Role |
|------|------|
| `lib/core/settings/` | Forgejo URL + PAT (secure storage) |
| `lib/core/forgejo/` | API client, PR/review models |
| `lib/core/agents/` | Registry (**SharedPreferences**), active-work client |
| `lib/core/mcp/` | Context + feedback client (HTTP + optional JSON-RPC) |
| `lib/core/deep_links/` | URL → go_router |
| `lib/features/home/` | Open PR list + filters |
| `lib/features/pr_detail/` | Detail, reviews, **AgentContextPanel** |
| `lib/features/agents/` | Agent CRUD UI |
| `lib/features/coordination/` | Work by repository |
| `docs/AGENT_MCP_CONTRACT.md` | Side-car contract |
| `docs/DEEP_LINKING.md` | App Links ops |
| `tool/mock_agent_server.dart` | Local demo agent |
| `tool/demo_avis_pbook.dart` | CLI live API smoke |

---

## 7. Tests / quality

```bash
export PATH="$HOME/bin:$HOME/flutter/bin:$PATH"
cd /home/avidullu/projects/Agent/agentforge
flutter analyze
flutter test
```

Expect analyze clean; tests include deep links, Forgejo client mocks, MCP client mocks, agent repository prefs, widgets.

---

## 8. What is intentionally not done

| Item | Notes |
|------|--------|
| Android SDK / phone APK | Not installed on WSL; Windows doctor missing Android toolchain |
| Visual Studio C++ | Needed for Windows **desktop** target (Chrome web works) |
| Hosted App Links (`assetlinks.json` / AASA) | Templates in `docs/well-known/`; not deployed on avis-pbook |
| Real agent wrappers | Mock only; contract is documented for Codex/Claude/Grok side-cars |
| Full MCP Streamable HTTP sessions | REST + simple JSON-RPC `/mcp`; not full session/SSE stack |
| CORS on Forgejo | Chrome demo uses disable-web-security; production mobile doesn’t need browser CORS |

---

## 9. Suggested next session prompts

1. **Verify agent add fix** on Chrome after pull; regression-test PAT still loads.  
2. **Android**: install Android Studio SDK on Windows, `flutter run` on phone/emulator.  
3. **Side-car**: wire a real local agent to `AGENT_MCP_CONTRACT.md`.  
4. **Forgejo CORS** (optional) if you want web without disable-web-security.  
5. **Polish**: diff view, timeline, markdown rendering for PR bodies.

---

## 10. Success criteria for the next owner

- [ ] `flutter test` + `flutter analyze` green  
- [ ] Chrome: Add agent persists after hot restart  
- [ ] Chrome: Open PR list still works with saved PAT  
- [ ] Mock agent: context + feedback on a PR detail page  
- [ ] Changes on Forgejo `main` (push `origin`, mirror `github` if desired)  

---

## 11. Recent commits (for orientation)

```
feat: complete Milestones 4–5 — MCP context + coordination
feat: Milestone 3 — agent registry and PR work badges
feat: Milestone 2 — PR comments and formal review actions
feat: Milestone 1 — Forgejo settings, open PR list, PR detail
feat: complete Milestone 0 deep-link platform wiring
```

(Plus this handoff’s agent-storage fix commit when landed.)
