# AgentForge — Session Handoff

**Updated:** 2026-07-18 (checkpoint — stop new feature PRs)
**Canonical repo:** https://avis-pbook.tail651ec3.ts.net/avidullu/agentforge
**GitHub mirror:** https://github.com/avidullu/agentforge
**Default branch:** `main` @ `3fec656` (verify with fetch)

## You are here

- **Paused opening new feature PRs** (owner request). Focus: review/land open
  work; tracker honesty; no AF-013+ starts until asked.
- **main** includes: AF-009…AF-012 PII S1–S4, AF-017 tests/lint (#15).
- **Open:** Forgejo **#13** AF-018 CI hardening (`codex/af018-ci-hardening`,
  tip `62e827c`) — mergeable; quality CI was red (~1m30s) not reproduced
  locally (159/159 + 39.24% coverage). Do not merge until quality green or
  documented MSI infra waiver.

## Shipped recently (2026-07-18)

| PR | Merge | Notes |
|----|-------|--------|
| #7 AF-009 | `93e06d7` | S1 config/PII tooling |
| #10 AF-010 | `0a42295` | origin-bound PATs |
| #12 AF-011 | `b0156cc` | AppConfig aliases |
| #14 AF-012 | `e5bec35` | synthetic test/tool fixtures |
| #15 AF-017 tests | `3fec656` | lint + tests; CI rewrite dropped |

## Open / blocked

| Item | State |
|------|--------|
| #13 AF-018 | OPEN — needs green quality CI after restack |
| AF-013…AF-015 | PLANNED — not started (PII continues after AF-012) |
| AF-017 Build Week | IN PROGRESS — owner gates; hard deadline 2026-07-22 05:30 IST |
| AF-008 / AF-002 | DECISION / BLOCKED (license, signing) |

## Ops

- Forgejo source of truth; push github main FF after merges.
- Own-PR reviews are COMMENT only.
- Runner capacity-constrained; mid-pipeline reds often infra when local green.
- Do **not** open new feature PRs unless owner re-enables the sequence.
