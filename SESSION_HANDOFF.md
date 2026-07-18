# AgentForge — Session Handoff

**Updated:** 2026-07-18 (AF-018-A shipped)
**Canonical repo:** https://avis-pbook.tail651ec3.ts.net/avidullu/agentforge
**GitHub mirror:** https://github.com/avidullu/agentforge
**Default branch:** `main` @ `8dfff7c` (verify with fetch)

## You are here

- **AF-018-A SHIPPED** as Forgejo #13 merge `8dfff7c` (tip `76ecdd8`).
  Stacked #16 cancellation/SDK path content included. Forgejo CI green
  (quality ~58s, Web build-smoke ~48s, required ~2s).
- **PII S1–S4 shipped** earlier: AF-009…AF-012.
- **No open PRs** required for the AF-018-A land (confirm with `pulls?state=open`).
- **Policy:** PR/push CI does **not** install Android SDK packages; Android
  SDK + APK + lint run on **Nightly** only (issue #17).
- Owner previously asked to pause **new feature** PRs (AF-013+); re-enable
  when ready. AF-017 Build Week deadline still open (2026-07-22 05:30 IST).

## Resume

```bash
export PATH="$HOME/bin:$HOME/flutter/bin:$PATH"
cd /home/avidullu/projects/Agent/agentforge
git fetch origin
git checkout main
git pull --ff-only origin main
# Local CI (same product steps as Forgejo quality):
bash tool/ci/run_local_ci.sh --lane quality --base-sha origin/main
bash tool/ci/run_local_ci.sh --lane build-smoke   # Web only
# Android (nightly path; needs ANDROID_SDK_ROOT):
# bash tool/ci/run_local_ci.sh --lane android-smoke
```

## Shipped recently (2026-07-18)

| PR | Merge | Notes |
|----|-------|--------|
| #7 AF-009 | `93e06d7` | S1 config/PII tooling |
| #10 AF-010 | `0a42295` | origin-bound PATs |
| #12 AF-011 | `b0156cc` | AppConfig aliases |
| #14 AF-012 | `e5bec35` | synthetic test/tool fixtures |
| #15 AF-017 tests | `3fec656` | lint + tests (no CI rewrite) |
| #13 AF-018-A | `8dfff7c` | CI harness, nightly Android, #16 stacked |

## Open / next

| Item | State |
|------|--------|
| AF-018-B…E | PLANNED (see AF-018 tracker) |
| AF-013…AF-015 | PLANNED (PII); not started until owner re-enables |
| AF-017 Build Week | IN PROGRESS — owner gates; deadline 2026-07-22 05:30 IST |
| AF-008 / AF-002 | DECISION / BLOCKED |
| Issue #17 | Policy: no per-PR Android SDK install (implemented; nightly once observed) |
| Forgejo runner | Jobs use registered `ubuntu-latest` act_runner on avis-pbook — **not** auto MSI/SURFACE |

## Ops

- Forgejo source of truth; push `github` main FF after merges.
- Own-PR reviews: COMMENT only.
- Runner capacity-constrained; local harness is the product-step source of truth.
- Nightly Android runs on avis-pbook Forgejo Actions when `nightly.yml` is on `main` (now yes) and the runner is online for schedules.
