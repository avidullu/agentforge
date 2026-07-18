# AgentForge — Session Handoff

**Updated:** 2026-07-18
**Canonical repo:** https://avis-pbook.tail651ec3.ts.net/avidullu/agentforge
**GitHub mirror:** https://github.com/avidullu/agentforge
**Default branch:** `main` (fetch before work)

The canonical shared handoff is
`OneDrive/Documents/claude-sync/memory/Agentforge/session-handoff.md`. This
checked-in copy is a repository-visible checkpoint.

## You are here

- **Hot path: Forgejo PR #10 (AF-010 / PII-redaction S2)** — origin-bound
  credential store. Branch `af-010-origin-bound-credentials`. Tip
  `c19daeb` (reviews 271/272: production origin index + URL-change PAT clear).
- AF-009 / PR #7 **SHIPPED** as `93e06d7` (verified tip `543b005`); MSI LGTM
  review 267; 76 tests + APK/Web green.
- AF-017 OpenAI Build Week submission is **IN PROGRESS**. Tracker:
  `docs/projects/AF-017-OpenAI-Build-Week-Submission.md`; hard deadline
  2026-07-22 05:30 IST. Owner registration/license/hosting gates remain open.
- AF-006 mobile design ingestion remains **IN PROGRESS** (A1 intake shipped).

## Next steps / open threads

1. Land AF-010 (#10): CI green + review; merge; then AF-011 from fresh
   `origin/main` (wire Dart to `AppConfig`; remove host literals from `lib/`).
2. Follow AF-017 deadline-critical ledger for Build Week submission.
3. Execute only unblocked rows in the AF-006 mobile-design tracker.
4. Resolve AF-008 license/distribution and AF-002 signing gates before
   claiming verified-link completion.
5. Treat AVIS-MSI as the primary local approval environment while the
   avis-pbook runner is capacity-constrained.

## Ramp-up kit

Read these after `git pull --ff-only`:

- `docs/08-Implementation-Plan-and-Milestones.md` — canonical project ledger.
- `docs/11-PII-Redaction.md` — AF-009…AF-015 architecture and gates.
- `docs/projects/AF-017-OpenAI-Build-Week-Submission.md` — submission tracker.
- `docs/projects/AF-006-Mobile-Design-Ingestion.md` — design-ingestion tracker.
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
