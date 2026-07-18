# AgentForge — Session Handoff (pick up here)

**Written:** 2026-07-18  
**Canonical repo:** https://avis-pbook.tail651ec3.ts.net/avidullu/agentforge  
**GitHub mirror:** https://github.com/avidullu/agentforge  
**Default branch:** `main` (verify with `git fetch origin && git rev-parse origin/main`)

**Also mirrored in-repo:** `SESSION_HANDOFF.md` (may lag; prefer this file when both exist).  
**Tracker (lifecycle rows only):** `docs/08-Implementation-Plan-and-Milestones.md`

---

## 1. 60-second status

| Item | State |
|------|--------|
| Product milestones 0–5 | On `main` earlier (app + Chrome demo worked) |
| **Hot path** | **PR #3** — AF-016 PII redaction **planning** (docs-only), **rev 8** tip **`3eeddcd`**, awaiting final LGTM |
| Secondary | **PR #4** — AF-006 design intake; may already be merged to main (verify); review asked private-host links + “seven vs eight” rows |
| WSL checkout | `/home/avidullu/projects/Agent/agentforge` |
| Windows clone | `C:\Users\avidu\Projects\agentforge` |
| Flutter Windows | `C:\Users\avidu\flutter` |
| Flutter WSL | `~/flutter` (+ `~/bin` unzip shim) |
| PAT (never commit) | `/home/avidullu/agentforge.pat` |
| Forgejo API token | `~/.config/forgejo/avis-pbook.token` |
| SSH | `forge:avidullu/agentforge.git` (port 2222) |

```
origin  → forge:avidullu/agentforge.git
github  → https://github.com/avidullu/agentforge.git
```

---

## 2. Resume commands

```bash
export PATH="$HOME/bin:$HOME/flutter/bin:$PATH"
cd /home/avidullu/projects/Agent/agentforge
git fetch origin
git checkout af-009-pii-redaction-bug
git pull --ff-only origin af-009-pii-redaction-bug
git log -3 --oneline
# Handoff tip: 3eeddcd  docs(af-009): rev 8 — D4-safe docs/11 evidence, clean header
```

Latest PR #3 comments:

```bash
TOKEN=$(cat ~/.config/forgejo/avis-pbook.token)
curl -sS -H "Authorization: token $TOKEN" \
  "https://avis-pbook.tail651ec3.ts.net/api/v1/repos/avidullu/agentforge/issues/3/comments?limit=15" \
  | python3 -c "import sys,json; d=json.load(sys.stdin);
[print(c['id'], c['created_at'], (c.get('body') or '').splitlines()[0][:100]) for c in d]"
```

---

## 3. PR #3 — AF-016 PII plan (HOT)

| Field | Value |
|-------|--------|
| URL | https://avis-pbook.tail651ec3.ts.net/avidullu/agentforge/pulls/3 |
| Branch | `af-009-pii-redaction-bug` |
| Tip | **`3eeddcd`** |
| Files | `docs/11-PII-Redaction.md`, `docs/08-Implementation-Plan-and-Milestones.md` |
| Scope | **Docs only** |

### Review arc (do not re-litigate closed architecture)

| Pass | Head | Result |
|------|------|--------|
| 250 | `c49c668` | S1 gate, pub hooks, iOS xcconfig, audit, tracker honesty → rev 5 |
| 253 | `12c2d88` | Dart overlay, native clean-clone, structural gate, stale SHA → rev 6 |
| 256 | `41fbf69` | Native no-escape-hatch, entitlements path, AF-016 evidence → rev 7 |
| **258 / ~#1676** | `9ef9136` | **docs/11 no private host**; header/tip wording → **rev 8 @ `3eeddcd`** |
| Response | `3eeddcd` | Comment ~1679 / review 259; **await LGTM** |

### Locked design (implementation after merge)

- D1 keep `com.<OWNER>.agentforge`; D2 neutral Kotlin path; D3 redact private FQDN; D4 evidence links
- Always-present `app_config.selected.dart` (no FS conditional import); commit synthetic only
- Tracked synthetic natives + **only** gitignored `*.local.*` / `Runner.entitlements.local` for real values
- Fail-closed **full-tree** blocklist only at **S7 / AF-015** (not S1)
- S1 = schema + generator + fixture/report-only guard

### Next steps (PR #3)

1. Read comments **after** `3eeddcd` / #1679.
2. **LGTM** → merge on Forgejo → `git push` mirror main → cut **AF-009** from `origin/main`.
3. More nits → docs-only fix; post reply via **file + python json** (see §6).
4. CI short reds (~1m) often = **runner restart**; full green ~18m (e.g. `12c2d88`). Re-run job if stuck.

---

## 4. PR #4 — AF-006 intake (secondary)

| Field | Value |
|-------|--------|
| URL | https://avis-pbook.tail651ec3.ts.net/avidullu/agentforge/pulls/4 |
| Branch | `codex/mobile-design-ingestion` |
| Note | May already be **merged** into main (handoff saw main advance with AF-006 files) — verify |
| Tracker | `docs/projects/AF-006-Mobile-Design-Ingestion.md` |

Review notes (if still open): fix new private-host links; “seven” vs **eight** ledger rows.

---

## 5. Demo (already proven)

```powershell
# Windows
$env:Path = "C:\Users\avidu\flutter\bin;" + $env:Path
cd C:\Users\avidu\Projects\agentforge
git pull
$ud = "$env:LOCALAPPDATA\agentforge-chrome-dev"
flutter run -d chrome --web-port=5173 `
  --web-browser-flag=--disable-web-security `
  --web-browser-flag=--user-data-dir=$ud
```

```bash
# PAT to clipboard (WSL)
tr -d '\n\r' < /home/avidullu/agentforge.pat | clip.exe
# Mock agent
dart run tool/mock_agent_server.dart   # :8765
```

Agents use **SharedPreferences** (web-safe). PAT uses secure storage.

---

## 6. Agent ops gotchas

1. Forgejo: **cannot REQUEST_CHANGES on own PR** → use COMMENT + issue comment.
2. Post review bodies from a **file** via Python `json.dumps` — shell ate backticks in f-strings.
3. Push **both** `origin` and `github`.
4. Runner `avis-msi-wsl-runner` shared with Khelsutra; restarts cancel jobs.
5. Living handoff path (Windows):  
   `C:\Users\avidu\OneDrive\Documents\claude-sync\memory\Agentforge\session-handoff.md`  
   (WSL: `/mnt/c/Users/avidu/OneDrive/Documents/claude-sync/memory/Agentforge/session-handoff.md`)

---

## 7. First prompts for next session

**A — Finish PII planning**  
> Fetch PR #3 tip; read comments after 3eeddcd. Merge if LGTM and start AF-009, or fix nits.

**B — AF-009 implementation** (only after #3 merges)  
> From origin/main: schema + generator + selected.dart + native synthetics + fixture-only check_no_pii. No full-tree fail-closed gate.

**C — AF-006**  
> If PR #4 still open, apply review fixes; else execute next unblocked AF-006 row from tracker.

---

## 8. Success criteria

- [ ] PR #3 merged or new review state after `3eeddcd`+
- [ ] GitHub main parity after merges
- [ ] This handoff tip SHA updated if work continues
