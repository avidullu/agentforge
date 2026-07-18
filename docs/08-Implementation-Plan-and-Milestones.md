# AgentForge tracked project

**Lifecycle:** IN PROGRESS

**Last verified:** 2026-07-18

**Canonical repository:** `avis-pbook` Forgejo

**Mirror:** GitHub `avidullu/agentforge`

**Product goal:** a private-runtime Flutter client for reviewing Forgejo pull
requests and coordinating trusted coding-agent endpoints over Tailscale.

This document is the source of truth for scope, gates, and shipped status.
README files and session handoffs link here; they do not maintain a parallel
milestone ledger.

## Current checkpoint

The repository contains useful M0-M5 prototype code, but the product is not
release-ready and no milestone has completed its real-device acceptance gate.
The verified baseline before the hardening PR was:

- Flutter 3.44.6 / Dart 3.12.2 on Windows.
- `flutter analyze --fatal-infos`: clean.
- 23 tests: passing; line coverage 25.47%.
- GitHub CI: green, but analyze/test only.
- Authenticated Forgejo reads: successful; review/comment writes not exercised.
- Android/iOS builds and real-device CUJs: not verified.
- Hosted Android/iOS association files: both returned HTTP 404 and templates
  still contained signing placeholders.
- Android SDK was absent at audit start. A user-local Java 17 / Android 36
  toolchain and Pixel 6 AVD are now installed and verified on the audit
  workstation.

AF-001 shipped through
[Forgejo #1](https://avis-pbook.tail651ec3.ts.net/avidullu/agentforge/pulls/1)
after passing these local gates:

- `dart format --output=none --set-exit-if-changed lib test tool`: clean.
- `flutter analyze --fatal-infos`: clean.
- `flutter test --coverage`: 46 tests passing; 575/1595 lines = 36.05%
  (baseline 25.47%, enforced floor 29%).
- `flutter build web --release --no-wasm-dry-run`: passing, followed by an
  interactive Chrome smoke of settings and durable agent persistence.
- `flutter build apk --debug`: passing on Android SDK 36 / Java 17.
- Pixel 6 Android 16 AVD: APK install and launch, Settings navigation, and
  warm plus fresh-APK `agentforge://pr/avidullu/agentforge/1` deep-link routes
  all verified.
- REST side-car mock: active work, PR context, rationale summary, idempotent
  feedback, and delivery receipt smoke verified.
- Android XML, iOS plists, association templates, web JSON, CI YAML, and
  `pubspec.yaml`: syntactically valid.
- Forgejo CI: successful on reviewed head `98b3749` after independently
  repeating format, analysis, 46 tests, 35.92% coverage, APK, and Web builds.
- Merge commit `7d5cb360a558ba285e6dc0ab13378085247a97b7` is present on both
  Forgejo `main` and GitHub `main`.

## Milestone truth

| Milestone | Honest status | Acceptance gate |
|---|---|---|
| M0 skeleton + deep links | **IMPLEMENTED; DEVICE GATE OPEN** | Gmail HTTPS link opens the exact PR on Android and iOS; authority, signing, and association files verified |
| M1 Forgejo settings + reads | **IMPLEMENTED; LIVE READ VERIFIED** | Pagination, credential/instance binding, native-device CUJ, and error-state tests |
| M2 comments + reviews | **PARTIAL** | Changes/checks/mergeability visible; review pinned to head; authenticated write and stale-head device tests |
| M3 agent registry + active work | **PROTOTYPE** | Authenticated HTTPS endpoint, per-agent health/error/freshness, durable provenance, device test |
| M4 agent context + feedback | **PROTOTYPE** | Standards-compliant MCP lifecycle or explicitly versioned side-car protocol, authentication, delivery receipts, real wrapper |
| M5 coordination UI | **UI IMPLEMENTED; SEMANTICS OPEN** | Durable relationships, partial failure/stale state, multi-machine device CUJ |

## Shippable work ledger

One row represents one independently reviewable PR. Every implementation PR
must update its row and this document's changelog.

| ID | Deliverable | Status | Dependency / gate | PR |
|---|---|---|---|---|
| AF-001 | Baseline audit, deep-link ownership, review head pinning, privacy and side-car safety | **SHIPPED** | Merged 2026-07-18; Forgejo CI green | [Forgejo #1](https://avis-pbook.tail651ec3.ts.net/avidullu/agentforge/pulls/1) |
| AF-002 | Release signing and hosted `assetlinks.json` / AASA; Gmail device CUJ | **BLOCKED** | Android signing identity, Apple Team ID, reachable association strategy | — |
| AF-003 | Changes/diff viewer, checks, conflicts, mergeability, reviewed-head guard | **PLANNED** | Forgejo API/UI design | — |
| AF-004 | Authenticated HTTPS agent protocol and compliant MCP adapter | **PLANNED** | Threat model, endpoint identity/pairing, stable MCP 2025-11-25 | — |
| AF-005 | Typed agent health, heartbeat TTL, partial failure, durable provenance | **PARTIAL** | AF-004 identity model | — |
| AF-006 | Design-handoff implementation and WCAG 2.1 AA pass | **PLANNED** | AF-003 information architecture | — |
| AF-007 | CI/release hardening: format, coverage floor, Android build, pinned toolchain | **SHIPPED IN AF-001** | Forgejo run 12 green | [Forgejo #1](https://avis-pbook.tail651ec3.ts.net/avidullu/agentforge/pulls/1) |
| AF-008 | Public-code/private-runtime licensing and data-boundary decision | **DECISION NEEDED** | Owner selects license/distribution model | — |
| AF-016 | PII redaction S0: **planning only** — approved bug doc + tracker rows (umbrella: [docs/11-PII-Redaction.md](11-PII-Redaction.md)) | **IN REVIEW** | — | Forgejo #3 @ tip of `af-009-pii-redaction-bug` (update SHA on merge) |
| AF-009 | PII redaction S1: schema + generator (build + `--release` unit validation) + tracked synthetic **defaults** + gitignored real gen + `check_no_pii` fixture tests; CI guard **report-only** on real tree (fail-closed only at AF-015) | **PLANNED** | AF-016 | — |
| AF-010 | PII redaction S2: origin-bound credential store + legacy-key deletion migration + upgrade test (app id unchanged ⇒ no sandbox issue) | **PLANNED** | AF-009 | — |
| AF-011 | PII redaction S3: wire Dart source to generated **const** `AppConfig` (`deep_link.dart`, `app_settings.dart`, UI strings, providers); remove host literals from `lib/` | **PLANNED** | AF-010 | — |
| AF-012 | PII redaction S4: tests/tool swap to synthetic fixtures; rename demo tool; remove display name / machine hint | **PLANNED** | AF-011 | — |
| AF-013 | PII redaction S5: Android neutral namespace `dev.agentforge.app` + Kotlin source-path move; **kept** `applicationId`; manifest host placeholder; AVD custom-scheme CUJ (verified links stay under AF-002) | **PLANNED** | AF-011 | — |
| AF-014 | PII redaction S6: iOS `AgentForge.xcconfig` include chain; preserve RunnerTests bundle id; entitlement host; `-showBuildSettings` both targets | **PLANNED** | AF-011 | — |
| AF-015 | PII redaction S7: docs/handoff redaction + Forgejo-PR-link rewrite (SHA + GitHub mirror) + `docs/CONFIGURATION.md` + well-known templates/render + tracked-`web/` sweep | **PLANNED** | AF-010, AF-012, AF-013, AF-014 | — |

> **PII redaction dependency note (rev 3).** Each branch starts from a
> fresh `origin/main` after its dependencies merge (topological, not
> sequential). Verified App-Link / Universal-Link gates remain under
> AF-002 (release signing), not in this workstream. Owner-locked crux
> decisions: keep `applicationId` / bundle id; neutralize Kotlin source
> path; redact the private Tailscale FQDN; rewrite Forgejo PR evidence as
> PR-number + short-SHA + GitHub-mirror link. See
> [docs/11-PII-Redaction.md](11-PII-Redaction.md) §1.1 and §9.

## Definition of Done

AgentForge can move to **DONE** only when all required ledger rows are complete
and the following statements are factually true:

- [ ] Android and iOS release identities are stable; verified links open the
  correct trusted Forgejo authority from Gmail on physical devices.
- [ ] The PR view exposes the reviewed head, changed files/diff, checks,
  conflicts, mergeability, and review ownership before formal actions.
- [ ] A head change invalidates the review state and blocks approval until the
  new code is inspected.
- [ ] Forgejo pagination, authentication expiry, rate limiting, empty/error
  states, and credential deletion have tests and usable UI.
- [ ] Agent endpoints are authenticated, identity-bound, HTTPS-only outside
  loopback development, revocable, capability-negotiated, and freshness-aware.
- [ ] Feedback has a correlation/idempotency key and observable
  queued/delivered/processing/replied/failed states without ambiguous retry.
- [ ] No UI or protocol asks for or exposes private chain-of-thought; agents
  provide an authored rationale summary.
- [ ] WCAG 2.1 AA contrast, semantics, 44dp targets, Dynamic Type/200% text,
  keyboard navigation, reduced motion, and screen-reader flows are verified.
- [ ] CI enforces formatting, analysis, tests, a non-regressing coverage floor,
  and Android build; iOS builds run on a signed macOS path.
- [ ] The runtime privacy boundary, public repository status, telemetry/font
  behavior, backup policy, and license are documented consistently.
- [x] Forgejo `main` and the GitHub mirror are synchronized after the shipped
  merge (verified at `7d5cb360`).

## Design and protocol decisions

- Forgejo is the source of truth for Git state and formal review actions.
- A PR identity must eventually be
  `{forgeInstanceId, owner, repo, number, headSha}`; a numeric PR alone is not
  globally unique.
- Agent identity is a stable endpoint/host ID, not a display name.
- Only an agent explicitly associated with a PR may receive its context by
  default. Linking another endpoint requires an explicit user action.
- Remote control traffic requires authenticated HTTPS. Plain HTTP is permitted
  only for a loopback development mock.
- The current REST side-car and isolated JSON-RPC read are prototypes, not a
  claim of MCP Streamable HTTP compliance.
- Formal merge is not a conversational quick action. It requires exact target,
  permission, checks, approvals, mergeability, and explicit confirmation.

## Next sequence

1. Select the release/license model for AF-008.
2. Decide release signing and Apple development/distribution strategy for
   AF-002; deploy both association files.
3. Run Gmail verified-link and persistence CUJs on physical Android/iOS
   devices once AF-002 signing and association gates are resolved.
4. Build AF-003 before treating in-app approval as a complete review workflow.
5. Threat-model and implement AF-004/AF-005 before connecting real agents.
6. Apply the component/state/accessibility plan in the design review.

## Changelog

- **2026-07-18 — AF-016 / PR #3 rev 6 (review 253):** Always-present
  `app_config.selected.dart` (no FS conditional import); tracked synthetic
  natives + optional `.local` overrides; decided pbxproj Runner/RunnerTests
  IDs; structural gate allows only synthetic origin; AF-016 evidence not
  pinned to obsolete rev-4 SHA. See [docs/11-PII-Redaction.md](11-PII-Redaction.md).

- **2026-07-18 — AF-016 / PR #3 rev 5 (review 250):** Stage fail-closed
  blocklist to S7 only; tracked synthetic defaults + gitignored real gen;
  iOS `AgentForge.xcconfig` include chain + RunnerTests identity; honest
  NUL-aware audit via tool; tracker D4 rewrite deferred truthfully to S7.
  See [docs/11-PII-Redaction.md](11-PII-Redaction.md) §12 review-250 table.

- **2026-07-18 — AF-016 / PR #3 rev 4 (third-pass resolution):** Planning
  doc no longer embeds live blocklist strings or private-host URLs (D4
  evidence only). §8.2 adds concrete D1 allow-list selectors. Bootstrap is
  checked-in synthetic gen + explicit generator/CI (pub hooks not required).
  S1 signing gate, web file list, and properties path wording corrected.
  See [docs/11-PII-Redaction.md](11-PII-Redaction.md) §12 third-pass table.

- **2026-07-18 — AF-009 BUG REVISED (rev 3, addressing PR #3 second-pass
  review id 246):** The second-pass review at head `9334af0` requested
  changes with eight findings (staged guard cannot stay green; no
  clean-clone bootstrap; generator graph misses const/native consumers +
  path errors; canonical CI fail-open; origin/association validation
  inconsistent; release/debug identity + credential migration incomplete;
  ledger/dependency graph wrong; audit not reproducible). Revision 3 of
  [`docs/11-PII-Redaction.md`](11-PII-Redaction.md) is grounded in four
  owner-locked crux decisions: **keep** the `applicationId` / bundle id
  (collapses finding 6); **neutralize** the Kotlin source path with a
  matching Gradle namespace (path ≠ id); **redact the private Tailscale
  FQDN** (strictest option); rewrite Forgejo PR evidence as PR-number +
  short-SHA + GitHub-mirror link. It also splits build-safe vs release
  validation, makes the canonical CI blocklist gate fail-closed, provides
  a NUL-safe reproducible audit (24 tracked files on `origin/main` @
  `37732b4`), and re-derives the workstream as a topological graph of
  **8 PRs** (AF-016 planning + AF-009…AF-015). Awaiting third-pass LGTM.
- **2026-07-18 — AF-001 / AF-007 SHIPPED:** Replaced aspirational M0-M5
  completion claims with
  verified statuses and gates. Added the design audit, deep-link/app-links
  corrections, trusted-host routing, review head pinning, system-font privacy,
  side-car fan-out restriction, feedback idempotency, HTTPS endpoint policy,
  heartbeat TTL, and CI hardening work. Forgejo PR link pending publication.
  Final review added per-endpoint partial-failure state, strict activity
  provenance, endpoint-bound cached state, immediate freshness authorization
  before context reads and feedback writes, debug-only Android/iOS loopback
  policies, retry-stable endpoint-bound feedback IDs, receipt enforcement and
  mock deduplication, redirect blocking, exact HTTPS-origin routing, and
  request-changes body validation. Published as ready-for-review
  [Forgejo #1](https://avis-pbook.tail651ec3.ts.net/avidullu/agentforge/pulls/1).
  The candidate passed 46 tests at 36.05% coverage, release-web and debug-APK
  builds, Chrome and Android 16 AVD UI smokes, a custom-scheme deep-link smoke,
  and the mock side-car receipt flow. Forgejo CI repeated the suite at 35.92%
  coverage and built both APK and Web artifacts. PR #1 merged as `7d5cb360`;
  Forgejo and GitHub `main` were then verified at the same commit. Tracker
  reconciliation is recorded in
  [Forgejo #2](https://avis-pbook.tail651ec3.ts.net/avidullu/agentforge/pulls/2).
- **2026-07-18 — baseline:** Direct commits created M0-M5 prototype surfaces;
  no tracked-project ledger or documented phone acceptance existed.
