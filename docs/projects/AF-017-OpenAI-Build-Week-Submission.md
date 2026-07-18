# AF-017 — OpenAI Build Week submission

**Lifecycle:** IN PROGRESS

**Last verified:** 2026-07-18

**Submission:** AgentForge

**Track:** Developer Tools

**Deadline:** 2026-07-21 17:00 PDT / 2026-07-22 05:30 IST

**Official source of truth:** https://openai.devpost.com/rules

**Goal:** submit a judge-accessible, privacy-safe AgentForge build that makes a
credible and evidenced case across OpenAI Build Week's four equally weighted
criteria: technological implementation, design, potential impact, and quality
of the idea.

This document is the sole progress tracker for the Build Week submission. The
repository-wide ledger and session handoff link here; the Devpost draft, PR
descriptions, video script, and chat history are supporting artifacts, not
parallel trackers.

## Current checkpoint

- AgentForge was created and substantially implemented during the eligible
  submission period, which began 2026-07-13 09:00 PDT. The repository history
  contains dated commits for the Flutter app, review safeguards, agent
  coordination, hardening, design intake, and privacy/configuration work.
- The strongest category fit is **Developer Tools**: AgentForge is a mobile and
  Web supervision surface for reviewing Forgejo pull requests and coordinating
  trusted coding-agent endpoints.
- The current exact-head suite is green on AVIS-MSI: generator idempotence,
  formatting, fatal-info analysis, 76 tests, 35.92% line coverage against the
  29% floor, report-mode PII scanning, debug APK, release Web, and
  `git diff --check`.
- The current repository is not submission-ready. It has no selected public
  license, depends on private infrastructure for its live data, lacks a
  judge-safe seeded demo and hosted test build, does not yet package Codex /
  GPT-5.6 evidence, and has no public video or completed Devpost entry.
- Product claims must stay narrow and honest. Diff/check review, authenticated
  production agent transport, verified physical-device links, full WCAG
  acceptance, and several final-design flows remain unfinished in their owning
  trackers.

## Submission thesis

**Working title:** AgentForge — mobile mission control for agentic coding

**One sentence:** AgentForge gives a developer a safe, exact-head-aware mobile
control surface for reviewing pull requests, seeing which coding agent owns
work, sending attributable feedback, and preventing stale or ambiguous review
actions.

**Target audience:** developers and small engineering teams running multiple
local or tailnet coding agents against Forgejo repositories.

**Problem:** agentic coding work is split across terminals, agent sessions,
source control, and private machines. A developer can easily review the wrong
commit, lose provenance, confuse transport failure with idle state, or expose
private infrastructure while trying to supervise work remotely.

**Demonstrated solution:** a coherent synthetic demo in which a judge opens a
pull request, sees its exact head and active agent provenance, sends feedback,
observes a head change invalidate review readiness, re-verifies the new head,
and completes a guarded review action without access to the owner's private
Forgejo or Tailscale environment.

## Official submission gates

These are derived from the official rules and overview. Re-verify them before
final submission because the official rules may change.

| Gate | Requirement | Evidence needed | Status |
|---|---|---|---|
| BW-G01 | Entrant registered and eligible; India is currently listed | Devpost joined state and owner confirmation | **OWNER ACTION** |
| BW-G02 | Project uses Codex with GPT-5.6 during the submission period | Dated commits plus model/session evidence | **OPEN** |
| BW-G03 | `/feedback` session ID for the thread containing most core functionality | Valid session ID recorded privately for the form and safely referenced in submission docs | **OPEN** |
| BW-G04 | Working, consistently runnable project | Hosted synthetic Web demo or equally frictionless test build | **OPEN** |
| BW-G05 | Public repository has relevant licensing, or private repository is shared with both judging accounts | License file and notices, or verified private-share evidence | **DECISION NEEDED** |
| BW-G06 | README explains Codex collaboration, acceleration, decisions, and GPT-5.6 contribution | Submission-specific README section with dated evidence | **OPEN** |
| BW-G07 | Public YouTube demo is under three minutes, has audio, and shows the working product plus Codex/GPT-5.6 use | Public URL and final timing/content audit | **OWNER ACTION** |
| BW-G08 | Developer tool has installation instructions, supported platforms, and a no-rebuild test path | README/test instructions plus hosted demo | **OPEN** |
| BW-G09 | Third-party code, fonts, screenshots, music, marks, and data are authorized | Dependency/license audit; synthetic assets; no unlicensed music | **OPEN** |
| BW-G10 | Submission stays free and accessible through judging | Availability check and owner commitment through judging | **OPEN** |

## Shippable PR ledger

Each row is one independently reviewable repository PR. Every implementation
PR must update its own row, affected gates/risks, and this document's changelog.

| ID | Deliverable | Status | Dependency / acceptance gate | PR |
|---|---|---|---|---|
| AF-017-A | Canonical tracker, judging thesis, owner-action register, deadline, and repository/handoff links | **IN PROGRESS** | Planning only; facts verified against official rules and shipped repository state | This branch |
| AF-017-B | Submission eligibility package: license/distribution decision, notices, third-party/asset audit, public/private judging-access decision | **BLOCKED** | Owner chooses license/distribution route; AF-008 lineage preserved; BW-G05/BW-G09 | — |
| AF-017-C | Judge-safe synthetic demo mode and deterministic fixtures; no dependency on private Forgejo, tokens, hosts, or agent endpoints | **PLANNED** | AF-009 synthetic config; exact-head and provenance semantics preserved; privacy tests | — |
| AF-017-D | Coherent golden-path product polish for Home → PR → agent feedback → head change → guarded re-review; responsive Web presentation and accessibility smoke coverage | **PLANNED** | AF-017-C; do not claim unimplemented diff/check or production MCP capabilities | — |
| AF-017-E | Submission evidence pack: Build Week README, eligible commit range, architecture/decision narrative, Codex/GPT-5.6 evidence, setup/platform/test instructions | **BLOCKED** | Owner supplies verified model and `/feedback` session evidence; AF-017-B–D facts only | — |
| AF-017-F | Hosted release Web demo plus reproducible deploy/runbook, availability smoke test, synthetic-only public configuration, and fallback APK/build artifact if appropriate | **BLOCKED** | AF-017-B–D; owner approves hosting destination and any external publication | — |
| AF-017-G | Submission media pack: storyboard, under-three-minute script, screenshots, captions/alt text, final YouTube and Devpost copy | **BLOCKED** | AF-017-D–F; owner records or approves narration and publishes YouTube video | — |
| AF-017-H | Final compliance and submission audit: exact submitted SHA, full MSI suite, clean public-tree/PII/license scan, working demo/video/repo links, Devpost submitted before deadline | **BLOCKED** | AF-017-B–G and all owner actions complete | — |

## Owner action register

These actions require the owner's identity, account, preference, or external
publication authority. Repository implementation can proceed around them only
where the ledger says it is safe.

| ID | Needed from owner | Recommended choice / instructions | Needed by | Status |
|---|---|---|---|---|
| OWNER-01 | Join OpenAI Build Week on Devpost and confirm the entrant/team name | Register now; send the exact display/team name to use in docs and video | 2026-07-18 | **OPEN** |
| OWNER-02 | Choose repository distribution route | Recommended: Apache-2.0 public license after confirming sole ownership; alternative: private repo shared with `testing@devpost.com` and `build-week-event@openai.com` | Before AF-017-B | **OPEN** |
| OWNER-03 | Confirm GPT-5.6/Codex evidence | Identify the session where most core eligible functionality was built; if model proof is insufficient, deliberately build AF-017-C/D in a new GPT-5.6 Codex session | Before AF-017-E | **OPEN** |
| OWNER-04 | Provide required `/feedback` session ID | Run `/feedback` in the qualifying core-build Codex thread; do not post private session content in the public repository | Before form completion | **OPEN** |
| OWNER-05 | Approve hosting destination | Recommended: public static Web demo with synthetic fixtures and no credentials; approve the exact host/account | Before AF-017-F | **OPEN** |
| OWNER-06 | Narration and YouTube publication | Record voice or approve compliant narration; upload publicly and provide the URL | 2026-07-21 IST | **OPEN** |
| OWNER-07 | Review and press final Devpost submit | Verify identity, IP/privacy attestations, links, category, and final text; submit before 05:30 IST on July 22 | 2026-07-21 IST | **OPEN** |

## Judging matrix

The four criteria are equally weighted. Evidence must be visible in the first
three minutes and understandable even if judges do not install the project.

| Criterion | Current evidence | Submission target | Principal gap |
|---|---|---|---|
| Technological implementation | Working Flutter app; Forgejo API; exact-head guard; agent freshness/provenance; idempotent feedback; strong tests/builds; detailed Codex commit trail | Demonstrate non-trivial implementation and explain two or three decisions where Codex accelerated work without replacing owner judgment | GPT-5.6/session evidence and concise technical narrative |
| Design | Functional screens plus audited final mock handoff and accessibility gap register | One visually coherent, responsive, keyboard-usable golden path with deterministic states | Current experience is incomplete and private-data dependent |
| Potential impact | Real problem: supervising multiple agents and reviewing the correct code from away from the workstation | Specific persona, failure story, before/after workflow, and credible local/private-team adoption path | Avoid broad “future of work” claims unsupported by the demo |
| Quality of idea | Mobile PR review combined with coding-agent provenance, freshness, feedback IDs, and stale-head safety | Present “review the work, not the agent's confidence” as the differentiator | Must distinguish from generic Git clients and chat dashboards |

## Demo contract

The judge path must work without credentials and without private infrastructure:

1. Open the hosted AgentForge demo and see a clearly labeled synthetic Forgejo
   workspace with no owner/private names or hosts.
2. Open a pull request whose repository, number, and exact head are visible.
3. See a coding agent's fresh work claim, endpoint identity, updated time, and
   authored rationale summary; never hidden chain-of-thought.
4. Send feedback with a stable client message ID and visible delivery outcome.
5. Trigger or select a deterministic head-change state that invalidates the
   earlier review readiness.
6. Re-open/re-verify the new exact head and demonstrate the guarded formal
   review action.
7. End on the coordination view with an honest explanation of what is live,
   synthetic, shipped, and still future work.

The demo must not imply that the current app includes a full diff/checks view,
production MCP transport, autonomous merging, verified mobile App Links, or
complete accessibility acceptance unless those capabilities ship and are
verified before recording.

## Risk register

| Risk | Pri | Impact | Mitigation / owner | Status |
|---|---|---|---|---|
| No public license selected | P0 | Public repository may fail submission requirements and creates ambiguous reuse rights | OWNER-02 + AF-017-B; preserve AF-008 decision lineage | **OPEN** |
| No proven GPT-5.6 core-build session or `/feedback` ID | P0 | Submission may be ineligible or score poorly on implementation evidence | OWNER-03/04; build meaningful demo work in a verified GPT-5.6 session if necessary | **OPEN** |
| Demo requires private Forgejo/Tailscale/PAT | P0 | Judges cannot test; credentials or private topology could leak | AF-017-C/F synthetic-only judge path and automated privacy gates | **OPEN** |
| Submission overclaims unfinished review/transport/accessibility features | P0 | Misleading demo, failed judging, or unsafe product expectations | Demo contract, README capability table, final claim audit | **OPEN** |
| Unlicensed/private design assets or third-party marks enter video/repo | P0 | IP/rules violation | AF-017-B/G use provenance-cleared synthetic assets and no unlicensed music | **OPEN** |
| Deadline compression | P1 | Good engineering but incomplete submission | Freeze scope to one golden path; daily gate review; owner actions front-loaded | **OPEN** |
| Hosted Web demo exposes writable actions or secrets | P1 | Security/privacy incident | Read-only/simulated fixtures, no tokens, CSP/static hosting, scan deploy output | **OPEN** |
| Video spends time on architecture instead of visible value | P1 | Judges may not reach differentiator within three minutes | Script to problem → golden path → Codex proof → impact; hard timing rehearsal | **OPEN** |
| Public build is inaccessible during judging | P1 | Test gate fails | Availability smoke test, documented fallback, keep free through judging | **OPEN** |

## Daily execution checkpoints

| Local date | Required outcome |
|---|---|
| 2026-07-18 | Tracker merged; Devpost joined; license/model/session/hosting decisions requested; AF-017-C branch ready |
| 2026-07-19 | Synthetic demo and core golden path merged; privacy and exact-head tests green |
| 2026-07-20 | Hosted demo, submission README/evidence pack, screenshots, and first video cut complete |
| 2026-07-21 | Full compliance rehearsal; final video public; all links tested from signed-out browser; Devpost submitted with buffer |
| 2026-07-22 05:30 IST | Hard deadline; no plan may depend on work after this time |

## Verification protocol

Every implementation PR must run the repository's full required suite on
AVIS-MSI:

```text
flutter pub get
dart run tool/generate_config.dart
git diff --exit-code -- tracked generated outputs
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze --fatal-infos
flutter test --coverage
dart run tool/check_coverage.dart coverage/lcov.info 29
dart run tool/check_no_pii.dart --mode=report --scope=tracked
flutter build apk --debug
flutter build web --release --no-wasm-dry-run
git diff --check
```

AF-017-C–H additionally require synthetic-demo tests, public-build content
scans, no-credential assertions, and signed-out testing of every submitted URL.

## Definition of Done

AF-017 may move to **DONE** only when:

- [ ] Every ledger row AF-017-A through AF-017-H is shipped or explicitly
  removed by a recorded superseding decision.
- [ ] OWNER-01 through OWNER-07 are complete with evidence; no owner action is
  inferred from repository changes.
- [ ] The exact submission SHA was created during the eligible period and the
  Build Week delta plus Codex/GPT-5.6 collaboration are documented accurately.
- [ ] A valid `/feedback` session ID is entered in Devpost without publishing
  private session contents in the repository.
- [ ] License/distribution, third-party dependency, asset, trademark, music,
  and privacy gates are satisfied.
- [ ] The hosted judge path runs free of charge without private credentials and
  remains available through judging; fallback instructions are tested.
- [ ] The under-three-minute public YouTube video has audio, shows the working
  golden path, explains Codex/GPT-5.6 use, and contains no private data or
  unauthorized material.
- [ ] README, Devpost copy, video, screenshots, test build, and shipped code
  make the same honest capability claims.
- [ ] The full exact-head MSI suite, coverage floor, generator diff gate,
  public-tree/deploy PII scans, and all submission-specific tests pass.
- [ ] Devpost shows the submission as entered before the official deadline and
  the final repository, demo, and video links work from a signed-out browser.
- [ ] Forgejo and GitHub `main` match after the final merge; completion evidence
  is recorded, inbound references are updated, and this tracker is moved to
  `docs/archives/past_projects/` with its lineage preserved.

## Changelog

- **2026-07-18 — AF-017 STARTED:** AgentForge selected as the recommended
  Developer Tools submission. Added the canonical lifecycle tracker, official
  and owner gates, eight-PR ledger, judging/demo contract, risks, daily
  checkpoints, verification protocol, and Definition of Done. No eligibility,
  license, model/session, hosting, video, or submission action is claimed
  complete.
