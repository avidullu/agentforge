# AF-018 — CI regression hardening

**Lifecycle:** IN PROGRESS

**Last verified:** 2026-07-18

**Owner:** AgentForge maintainers

**Canonical repository:** owner Forgejo; GitHub is the synchronized public
mirror.

This document is the source of truth for AF-018. Its rows are independently
shippable pull requests. The project moves `IN PROGRESS -> DONE -> ARCHIVED`
only when every required row and the Definition of Done are factually complete.

## Why this project exists

The workflow inherited from AF-001/AF-007 catches basic format, analysis,
test, coverage, Android, and Web failures, but it does not yet provide a
reliable required-check contract:

- one serial job delays fast feedback behind Android setup and gives no stable
  aggregate status for branch protection;
- a 29% line floor permits hundreds of new uncovered lines against the current
  35.92% baseline, and changed files have no coverage gate;
- dependency resolution is not lock-enforced;
- long SDK/build phases can be silent for minutes, leaving operators unable to
  distinguish useful work from a hung runner;
- the shared 15 GiB runner permits two 8 GiB Gradle heaps and has repeatedly
  restarted or cancelled jobs during SDK/NDK work;
- Android packages are not validated after download and partial installs are
  not repaired safely;
- there is no required integration, accessibility, visual, device, iOS, or
  release lane;
- `main` has no branch protection.

The AF-009 exact-head verification at `543b005` passed 76 randomized tests,
573/1595 lines (35.92%), format, analysis, debug APK, release Web, and clean
generated outputs. Forgejo #7 nevertheless merged as public-mirror commit
[`93e06d7`](https://github.com/avidullu/agentforge/commit/93e06d79fd78762b8bfa4a8dda45891636730a41)
while its runner status was still pending. An independent post-merge pass also
found that one test could discover a developer's gitignored real config and
rewrite a tracked generated file. AF-018-A removes that unsafe subprocess and
makes both runner observability and exact-check enforcement first-class.

## Progress ledger

| Row | Independently shippable deliverable | Status | Dependency / gate | PR / evidence |
|---|---|---|---|---|
| AF-018-A | Deterministic quality/build lanes, observable long commands, generated/lock cleanliness, 35.5% global + 80% changed-line coverage, bounded Gradle, exact Android SDK repair, stable required status, unsafe AF-009 test removal | **LOCAL GATES GREEN — PR PENDING** | Re-cut from current `origin/main`; exact-head Forgejo required context green | — |
| AF-018-B | Required high-risk widget, semantics, keyboard, 200% text, and failure-state contracts | **PLANNED** | AF-006 A2 design primitives; AF-018-A | — |
| AF-018-C | Hermetic loopback transport tests for Forgejo/MCP pagination, auth, redirects, timeouts, retries, malformed data, and idempotency | **PLANNED** | AF-004 protocol decisions; AF-018-A | — |
| AF-018-D | Pinned-font golden/semantics matrix with manual, reviewable updates | **PLANNED** | AF-006 implementation screens; AF-018-B | — |
| AF-018-E | Scheduled Android AVD, release/manifest, release-Web boot, and macOS no-sign iOS lanes | **PLANNED** | Runner labels and macOS executor; AF-002 signing where applicable | — |

## AF-018-A required contract

### Fast `quality` lane

The lane runs before Java/Android setup and must complete within 15 minutes:

1. SHA-pinned, read-only checkout with full history and no persisted Git
   credential.
2. Flutter 3.44.6 with runner cache disabled until Forgejo cache authentication
   is repaired.
3. `flutter pub get --enforce-lockfile` plus an exact `pubspec.lock` diff.
4. Synthetic config generation followed by byte-clean tracked outputs.
5. formatting and fatal-info analysis with `--no-pub` where supported.
6. the full randomized Flutter suite at seed `424242`, collecting line and
   branch data. Branch coverage is collected but not claimed as gated until
   the pinned toolchain emits usable `BRDA` records.
7. a 35.5% global line floor and 80% coverage on changed executable
   `lib/**/*.dart` lines. A wholly new source absent from LCOV counts likely
   code lines as uncovered so an unimported file cannot evade the gate.
8. the honest report-only PII inventory. This is not a fail-closed privacy gate;
   that remains AF-015.
9. shell syntax, whitespace, generated output, lockfile, and final tracked-tree
   cleanliness checks.

### Observable slow `build-smoke` lane

This lane runs only after `quality` passes and must complete within 40 minutes:

- every command streams its native output;
- a timestamped `START` line prints the shell-escaped command;
- a timestamped heartbeat prints every 20 seconds for Flutter phases and every
  30 seconds for Android phases;
- `PASS`/`FAIL`, exit status, and elapsed seconds are always printed;
- runner disk/memory, exact revisions, Java/Flutter versions, SDK root, and
  artifact byte sizes are visible without printing credentials;
- release Web builds before Android setup, giving a useful result while SDK
  work is still queued;
- Android command-line tools are pinned, and platform tools, platform 36,
  build-tools 36.0.0, and NDK 28.2.13676358 are installed with three attempts;
- only an exact allow-listed incomplete package directory may be removed;
- the debug APK and `lintDebug` must pass, with Gradle limited to 4 GiB heap,
  1 GiB metaspace, two workers, and no parallel project execution.

The workflow serializes all AgentForge runs with `cancel-in-progress: false`.
This deliberately queues old heads instead of cancelling a build mid-SDK
write. Operators may cancel a stale queued run explicitly. `workflow_dispatch`
provides a retry path without empty commits.

### Stable required status and branch protection

An `always()` aggregate job named `required` fails unless both lanes succeed.
After the workflow merges and Forgejo emits the exact context, protect `main`
using that observed context (expected: `CI / required (pull_request)`), require
an up-to-date branch, and apply the rule to administrators. Do not guess the
context string before it exists. With a single owner, AF-018-A does not invent
a second mandatory approval; status and stale-head protection are the merge
gates.

## Coverage ratchet

- Initial global floor: **35.5%**. The exact observed baseline varies between
  35.92% and 36.05%, so this allows about 24 uncovered lines rather than the
  roughly 387 lines allowed by 29%.
- Changed executable line floor: **80%**.
- After three deterministic green `main` runs, raise the global floor to
  36.0%.
- Thereafter raise it in 0.5-point increments whenever the lowest of three
  consecutive green `main` runs is at least 0.75 points above the floor.
- Never lower a floor without recording the reason and approval in this
  tracker changelog.

## Definition of Done

- [ ] AF-018-A is merged from an exact-head green Forgejo run; GitHub `main`
  is synchronized to the same merge commit.
- [ ] Forgejo `main` protects the exact emitted `required` context, rejects
  outdated heads, and applies the rule to administrators.
- [ ] Long operations show timestamped progress at least every 30 seconds and
  finish with elapsed time and artifact evidence.
- [ ] Lock, generated config, formatting, fatal analysis, the full randomized
  suite, global coverage, changed-line coverage, Web, APK, Android lint,
  shell syntax, and tree cleanliness are required.
- [ ] No test reads a developer's real config or mutates tracked checkout
  outputs; this is tested using isolated temporary fixtures.
- [ ] AF-018-B covers the priority UI/persistence/accessibility regression
  contracts and is required on pull requests.
- [ ] AF-018-C covers the priority transport contracts and is required on pull
  requests.
- [ ] AF-018-D has a stable, reviewable visual baseline and semantics output.
- [ ] AF-018-E runs on its documented schedule and reports device/release/iOS
  failures without weakening pull-request gates.
- [ ] Completion claims are rechecked against shipped code, inbound tracker
  references are updated, and this document is moved to
  `docs/archives/past_projects/` with its lineage preserved.

## Changelog

- **2026-07-18 — AF-018-A local gates green:** The candidate passed Dart
  formatting, fatal-info analysis, 97 randomized tests, unchanged 573/1595
  line coverage (35.92% against the new 35.5% floor), changed-line tool unit
  tests, generated/lock/tree checks, report-only PII inventory, release Web
  (`index.html` 1,559 bytes), debug APK (157,180,040 bytes), and Android lint
  (0 errors; 7 existing warnings). `actionlint` 1.7.12, YAML parsing, Bash
  syntax, and heartbeat success/failure propagation passed. Android lint also
  exposed and this change fixes an omitted `includeSubdomains="false"` on the
  debug-only `127.0.0.1` network-security entry. Git Bash cannot launch this
  workstation's CRLF Flutter shell shim through the Linux-oriented heartbeat
  wrapper; native Windows Flutter gates passed, while exact wrapper + workflow
  behavior still requires the Linux Forgejo run before merge.

- **2026-07-18 — AF-018-A started:** Created the regression-hardening tracker
  from merged AF-009 baseline `93e06d7`. Defined observable fast/slow lanes,
  stable aggregation, deterministic dependency/test inputs, coverage ratchets,
  bounded Android provisioning, and post-merge branch protection. Included
  removal of the AF-009 real-checkout release subprocess regression found in
  the post-merge review.
