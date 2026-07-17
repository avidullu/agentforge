# AgentForge — Handoff Document

**Last updated**: 2026-07-18  
**Status**: Milestones **0–5 implemented** on `main`  
**Full session handoff**: see [`SESSION_HANDOFF.md`](./SESSION_HANDOFF.md) (bugfix for Add agent + ops)

---

## Goal

Personal Flutter app: review Forgejo PRs (deep-linked from Gmail) and coordinate local coding agents over Tailscale via MCP.

---

## Repository

| | |
|--|--|
| Canonical | https://avis-pbook.tail651ec3.ts.net/avidullu/agentforge |
| SSH | `forge:avidullu/agentforge.git` |
| GitHub | https://github.com/avidullu/agentforge |
| WSL | `/home/avidullu/projects/Agent/agentforge` |
| Windows demo | `C:\Users\avidu\Projects\agentforge` |
| Flutter (Windows) | `C:\Users\avidu\flutter` |
| PAT file | `/home/avidullu/agentforge.pat` (do not commit) |

---

## Milestone status

| M | Feature | Status |
|---|---------|--------|
| 0 | Deep linking | Done |
| 1 | Forgejo settings + PR list + detail | Done |
| 2 | Comments + Approve / Request changes | Done |
| 3 | Agent registry + active-work badges | Done |
| 4 | Agent context panel (plan/reasoning/feedback) | Done |
| 5 | Coordination view + home filters | Done |

---

## Run (Windows Chrome demo)

```powershell
$env:Path = "C:\Users\avidu\flutter\bin;" + $env:Path
cd C:\Users\avidu\Projects\agentforge
git pull
$ud = "$env:LOCALAPPDATA\agentforge-chrome-dev"
flutter run -d chrome --web-port=5173 `
  --web-browser-flag=--disable-web-security `
  --web-browser-flag=--user-data-dir=$ud
```

PAT: copy from WSL `clip.exe` via `tr -d '\n\r' < ~/agentforge.pat | clip.exe`, Save in Settings.

### Mock agent side-car (M3–M4 demo)

```bash
# WSL or Windows dart
cd /home/avidullu/projects/Agent/agentforge   # or Windows path
dart run tool/mock_agent_server.dart          # http://127.0.0.1:8765
```

In app → Agents → add agent with MCP URL `http://127.0.0.1:8765`  
(For phone/other machine use Tailscale IP.)

---

## Agent contract

See `docs/AGENT_MCP_CONTRACT.md`.

---

## Next (optional / ops)

- Android SDK + real device install
- Host `docs/well-known/*` on avis-pbook for verified App Links
- Real agent wrappers (Codex/Claude/Grok) implementing the HTTP contract
- Full MCP Streamable HTTP sessions if side-cars require it
