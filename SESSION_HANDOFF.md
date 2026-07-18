# AgentForge — Session Handoff

**Updated:** 2026-07-18
**Canonical repo:** https://avis-pbook.tail651ec3.ts.net/avidullu/agentforge
**GitHub mirror:** https://github.com/avidullu/agentforge
**Shipped baseline:** `main` at `93e06d7` before this reconciliation PR; Forgejo and GitHub matched.

The canonical shared handoff is
`OneDrive/Documents/claude-sync/memory/Agentforge/session-handoff.md`. This
checked-in copy is a repository-visible checkpoint.

## You are here

- AF-017 OpenAI Build Week submission work is **IN PROGRESS**. Its canonical
  tracker is `docs/projects/AF-017-OpenAI-Build-Week-Submission.md`; the hard
  deadline is 2026-07-22 05:30 IST. Owner registration, license,
  GPT-5.6/`/feedback`, hosting, and YouTube actions remain open. Tracker
  bootstrap AF-017-A shipped via Forgejo #9 as `798b563`.
- Forgejo PR #7 (AF-009 / PII-redaction S1) merged as `93e06d7` from verified
  tip `543b005`; GitHub `main` was fast-forwarded to the same merge SHA.
- All review findings 261 and 263–266 were resolved. The final AVIS-MSI suite
  passed generator byte-idempotence, Dart formatting, `flutter analyze
  --fatal-infos`, 76 tests, 35.92% line coverage (29% floor), report-mode PII
  scanning, debug APK, release Web, and `git diff --check`.
- Forgejo run 49 was pending on the restarting/capacity-constrained runner.
  The exact-head MSI approval-environment waiver was documented in final
  review 267; no repository failure was waived.
- AF-006 mobile design ingestion remains **IN PROGRESS**; its A1 intake row is
  shipped. Preserve the untracked `App building assistance/` source assets.

## Next steps / open threads

1. Follow AF-017's deadline-critical ledger: merge the tracker, resolve owner
   gates, then build the judge-safe synthetic demo and coherent golden path.
2. Start AF-010 only from a fresh `origin/main`: origin-bound credential store,
   legacy-key deletion migration, and upgrade tests.
3. Execute only unblocked rows in the AF-006 mobile-design tracker.
4. Resolve AF-008's license/distribution decision and AF-002's signing and
   association-file gates before claiming verified-link completion.
5. Continue treating AVIS-MSI as the primary local approval environment while
   the avis-pbook runner is being upgraded.

## Ramp-up kit

Read these after `git pull --ff-only`:

- `docs/08-Implementation-Plan-and-Milestones.md` — canonical project ledger.
- `docs/projects/AF-017-OpenAI-Build-Week-Submission.md` — submission tracker.
- `docs/11-PII-Redaction.md` — AF-009…AF-015 architecture and gates.
- `docs/projects/AF-006-Mobile-Design-Ingestion.md` — design-ingestion tracker.
- `.github/workflows/ci.yml` — required repository verification suite.
- `tool/generate_config.dart`, `tool/config_model.dart`, and
  `tool/check_no_pii.dart` — shipped AF-009 tooling.

## Key decisions

- Forgejo is the source of truth; GitHub is a non-force fast-forward mirror.
- Only synthetic configuration is tracked. Real configuration writes only
  gitignored local overrides and must never leak through logs or CI artifacts.
- Full-tree fail-closed PII enforcement remains AF-015; AF-009 intentionally
  ships report-only scanning on the real tree plus fail-closed fixture tests.
- Never force, rebase, reset, or stage unrelated files in the shared checkout.
