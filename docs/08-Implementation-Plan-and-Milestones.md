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

The AF-001 candidate has now passed these local gates:

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
| AF-001 | Baseline audit, deep-link ownership, review head pinning, privacy and side-car safety | **IN REVIEW** | Forgejo PR checks and review | [Forgejo #1](https://avis-pbook.tail651ec3.ts.net/avidullu/agentforge/pulls/1) |
| AF-002 | Release signing and hosted `assetlinks.json` / AASA; Gmail device CUJ | **BLOCKED** | Android signing identity, Apple Team ID, reachable association strategy | — |
| AF-003 | Changes/diff viewer, checks, conflicts, mergeability, reviewed-head guard | **PLANNED** | Forgejo API/UI design | — |
| AF-004 | Authenticated HTTPS agent protocol and compliant MCP adapter | **PLANNED** | Threat model, endpoint identity/pairing, stable MCP 2025-11-25 | — |
| AF-005 | Typed agent health, heartbeat TTL, partial failure, durable provenance | **PARTIAL** | AF-004 identity model | — |
| AF-006 | Design-handoff implementation and WCAG 2.1 AA pass | **PLANNED** | AF-003 information architecture | — |
| AF-007 | CI/release hardening: format, coverage floor, Android build, pinned toolchain | **IN REVIEW IN AF-001** | Forgejo PR checks | [Forgejo #1](https://avis-pbook.tail651ec3.ts.net/avidullu/agentforge/pulls/1) |
| AF-008 | Public-code/private-runtime licensing and data-boundary decision | **DECISION NEEDED** | Owner selects license/distribution model | — |

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
- [ ] Forgejo `main` and the GitHub mirror are synchronized after each merge.

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

1. Publish AF-001, verify Forgejo checks, merge, and synchronize GitHub.
2. Decide release signing and Apple development/distribution strategy for
   AF-002; deploy both association files.
3. Run Gmail verified-link and persistence CUJs on physical Android/iOS
   devices once AF-002 signing and association gates are resolved.
4. Build AF-003 before treating in-app approval as a complete review workflow.
5. Threat-model and implement AF-004/AF-005 before connecting real agents.
6. Apply the component/state/accessibility plan in the design review.

## Changelog

- **2026-07-18 — AF-001:** Replaced aspirational M0-M5 completion claims with
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
  and the mock side-car receipt flow.
- **2026-07-18 — baseline:** Direct commits created M0-M5 prototype surfaces;
  no tracked-project ledger or documented phone acceptance existed.
