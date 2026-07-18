# AgentForge — Session Handoff

**Updated:** 2026-07-18
**Canonical repo:** https://avis-pbook.tail651ec3.ts.net/avidullu/agentforge
**GitHub mirror:** https://github.com/avidullu/agentforge
**Default branch:** `main` (fetch before work)

The canonical shared handoff is
`OneDrive/Documents/claude-sync/memory/Agentforge/session-handoff.md`. This
checked-in copy is a repository-visible checkpoint.

## You are here

- **Hot path: AF-011 / PII-redaction S3** — wire Dart to const `AppConfig`.
  Branch `af-011-wire-appconfig` (from `origin/main` @ `0a42295`).
- AF-010 / PR #10 **SHIPPED** as `0a42295` (tip `6dd4b84`); CI green + LGTM 276.
- AF-009 / PR #7 **SHIPPED** as `93e06d7`.
- AF-017 OpenAI Build Week submission is **IN PROGRESS**. Tracker:
  `docs/projects/AF-017-OpenAI-Build-Week-Submission.md`; hard deadline
  2026-07-22 05:30 IST. Owner registration/license/hosting gates remain open.
- AF-006 mobile design ingestion remains **IN PROGRESS** (A1 intake shipped).

## Next steps / open threads

1. Land AF-011: finish wire + open Forgejo PR; CI + review; merge.
2. AF-012 from fresh `origin/main` after #11 lands (tests/tool synthetic swap).
3. Follow AF-017 deadline-critical ledger for Build Week submission.
4. Execute only unblocked rows in the AF-006 mobile-design tracker.
5. Resolve AF-008 license/distribution and AF-002 signing gates before
   claiming verified-link completion.

## Ramp-up kit

Read these after `git pull --ff-only`:

- `docs/08-Implementation-Plan-and-Milestones.md` — canonical project ledger.
- `docs/11-PII-Redaction.md` — AF-009…AF-015 architecture and gates.
- `docs/projects/AF-017-OpenAI-Build-Week-Submission.md` — submission tracker.
- `lib/core/config/app_config.dart` — exports generated `AppConfig`.
- `lib/core/settings/settings_repository.dart` — AF-010 origin-bound PATs.
- `tool/generate_config.dart` / `tool/check_no_pii.dart` — AF-009 tooling.

## Key decisions

- Forgejo is the source of truth; GitHub is a non-force fast-forward mirror.
- Only synthetic configuration is tracked. Real config writes only gitignored
  local overrides and must never leak through logs or CI artifacts.
- PATs are origin-scoped (`forgejo_token::<origin>`); legacy unscoped keys are
  deleted on load and never auto-bound (AF-010).
- Full-tree fail-closed PII enforcement remains AF-015.
- Never force, rebase, reset, or stage unrelated files in the shared checkout.
