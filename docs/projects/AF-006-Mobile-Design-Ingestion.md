# AF-006 — Mobile design ingestion and implementation

**Lifecycle:** IN PROGRESS

**Last verified:** 2026-07-18

**Canonical repository:** owner Forgejo

**Mirror:** GitHub `avidullu/agentforge`

**Goal:** turn the owner-selected final mobile mocks into a safe,
implementation-ready Flutter design system and complete, accessible product
flows without weakening AgentForge's review, identity, privacy, or transport
guarantees.

This document is the sole progress tracker for AF-006. The repository-wide
ledger links here; the design audit and handoff package are supporting evidence,
not parallel trackers.

## Current checkpoint

- The selected source is
  `App building assistance/Final-App building assistance/design_handoff_agentforge_mobile`.
- A 24-file, 973,099-byte inventory was audited. Exact hashes and dimensions
  are recorded in the tracked
  [`SOURCE-MANIFEST.md`](../../design/handoffs/agentforge-mobile/2026-07-18-final/SOURCE-MANIFEST.md).
- The disclosure-safe source token file is tracked byte-for-byte as
  `tokens.visual-source.json`; it is not safe to import directly because
  several contrast values fail WCAG AA.
- Source images and executable prototype files are quarantined outside Git.
  Three screenshots expose private host/namespace data, two pairing exports are
  broken duplicates, the three concept `.png` files contain JPEG payloads, and
  copied/generated asset provenance is missing.
- The existing Flutter app already contains Home, PR detail/context, Agents,
  Settings, exact-head formal review safeguards, endpoint-bound context, and
  delivery ID foundations. It does not contain the final four-tab shell,
  Summary, Agent Detail, secure pairing, a Changes/diff/checks surface, or the
  full state/accessibility matrix.
- Static prototype/code inspection is complete. The main agent's local
  `file://` runtime attempt was blocked by the in-app browser URL policy, so
  interaction behavior was not independently runtime-verified in that browser.
  No bypass was attempted.

## Source precedence and ingest boundary

When artifacts conflict, use this order:

1. Shipped code and normative repository contracts, especially
   `docs/AGENT_MCP_CONTRACT.md`, the repository-wide ledger, and security tests.
2. Accepted decisions and closed gaps in this tracker.
3. Sanitized, provenance-cleared canonical exports created by AF-006-A2.
4. Source screenshots `01`–`09` as visual direction only.
5. Source screenshots `10`–`11`, concept mocks, HTML prototype, sample data,
   TypeScript types, prompt, and draft API docs as evidence only.

The handoff's “final/pixel-perfect” language applies only to visual direction.
It does not make unsafe controls, inaccessible markup, private defaults, or
draft protocols normative. Unspecified behavior stays open in this tracker.

## Shippable PR ledger

Each row is one independently reviewable PR. Every implementation PR must
update its own row, the affected gap rows, and this document's changelog.

| ID | Deliverable | Status | Dependency / acceptance gate | PR |
|---|---|---|---|---|
| AF-006-A1 | Safe intake index, source hashes, final-pass audit, gap register, code map, pickup plan | **SHIPPED** | Docs/assets only; no raw private binaries or prototype contracts enter Git | Forgejo #4; [merge `8b10705`](https://github.com/avidullu/agentforge/commit/8b10705f3e5252441a8b7beb3e991e3699a270d5) |
| AF-006-A2 | Canonical sanitized visual package: portrait exports, real Add Agent/pairing states, provenance/notices, MIME-correct assets, checksum manifest | **BLOCKED** | AF-008 license/provenance decision; private-data redaction; regenerated distinct captures | — |
| AF-006-B | Semantic Flutter tokens and reusable accessible primitives | **BLOCKED** | G023 theme decision plus G008/G015/G016 acceptance values; no failing source color imported verbatim | — |
| AF-006-C | Four-tab app shell plus Home state-complete visual implementation | **BLOCKED** | AF-006-B; router/deep-link regression tests; agent carousel waits for AF-005 | — |
| AF-006-D | PR detail tabs, persistent exact-target header, Conversation/Context presentation, Changes/Activity integration | **BLOCKED** | AF-003 review data and information architecture; AF-004/005 feedback/identity state; AF-006-B | — |
| AF-006-E | Agent endpoints, Agent Detail, Settings, secure pairing and acknowledged control states | **BLOCKED** | AF-004 topology/auth/pairing; AF-005 health/provenance; AF-006-B | — |
| AF-006-F | Summary, analytics provenance, notification preferences and privacy-safe deep links | **BLOCKED** | G017/G018 policy decisions; paginated Forgejo data; AF-005 attribution | — |
| AF-006-G | Golden/semantics matrix, 200% text, keyboard/reduced motion, Android/iOS device acceptance | **BLOCKED** | AF-006-B–F complete; AF-002 for signed physical verified-link acceptance | — |

## Design gap register

Priority means implementation risk, not visual polish. `P0` gaps block any claim
that the corresponding surface is safe or implementation-ready.

| Gap | Pri | Evidence / problem | Required resolution | Owner row / gate | Status |
|---|---|---|---|---|---|
| AF6-G001 | P0 | Source screenshots `01`, `08`, `09` disclose private host/namespace data; binaries and copied frame have no license/provenance record | Sanitize private values; document source/tool/model/owner/license for every binary and frame-derived export; add notices and OCR/denylist scan | AF-006-A2 / AF-008 | **BLOCKED** |
| AF6-G002 | P0 | Add Agent and Pairing captures are byte-identical and show no sheet; concept `.png` files are JPEG payloads; all screen exports are landscape crops with scrollbars | Regenerate distinct full-portrait canonical captures, correct MIME/extensions, include sheets/keyboard/error/confirmation states, then hash them | AF-006-A2 | **OPEN** |
| AF6-G003 | P0 | Handoff assumes one central MCP broker with server-minted pairing; shipped app uses direct per-agent sidecars | AF-004 must select and threat-model topology, migration, identity, credential storage, and capability discovery before pairing/control UI | AF-004 / AF-006-E | **BLOCKED** |
| AF6-G004 | P0 | Design types route by numeric `prId` and mutable display name | Every action/state key must use `{forgeInstanceId, owner, repo, number, headSha}`, `{agentEndpointId, hostId}`, `clientMessageId`, and `deliveryId` | AF-003/004/005 / AF-006-D,E | **PARTIAL** |
| AF6-G005 | P0 | "LGTM, merge it" is a chat macro; Agent Detail exposes "Merge without review" | Remove both. Formal merge is outside conversational feedback and requires exact target/head, checks, approvals, permissions, mergeability, audit, and explicit confirmation | AF-003 / AF-006-D,E | **RESOLVED IN CODE** — shipped Flutter app never carried these over. The prototype source still contains them (quarantined). Formal merge is not yet implemented (AF-003) but the unsafe quick-actions were correctly avoided. |
| AF6-G006 | P0 | Files shows only path and +/- counts; no diff, checks, conflicts, mergeability, review ownership, or stale-head state | Rename to Changes; add diff/viewed state, checks, conflicts, mergeability, exact head, requested reviewers and Forgejo fallback before complete review claims | AF-003 / AF-006-D | **BLOCKED** |
| AF6-G007 | P0 | Prototype/draft docs parallel-write Forgejo and MCP with no reconciliation; timers mutate the last message/current PR | Define one durable source of truth plus per-leg IDs, idempotency, ambiguous-write handling, receipts, partial failure, persistence and adapter-driven replies | AF-004/005 / AF-006-D | **PARTIAL** |
| AF6-G008 | P0 | Prototype has 34 `onClick` handlers but zero buttons, ARIA attributes, roles or tab stops; textarea is the only form control | Flutter surfaces need native semantic buttons/tabs/switches/dialogs, names/roles/values, focus order/visibility, modal focus, live announcements and 44×44dp semantic targets | AF-006-B,G | **OPEN** |
| AF6-G009 | P0 | Pair token is visible before pairing, then a timer auto-registers an agent; no TTL, identity confirmation, cancel, expiry, error, duplicate or revoke states | Implement authenticated minting and a real state machine: minting, ready/TTL, copied, waiting, registered, expired, rejected, duplicate, cancelled, revoked, network error | AF-004 / AF-006-E | **BLOCKED** |
| AF6-G010 | P0 | Source hard-codes private host/token examples; Settings implies token suffix display/reveal; notification previews may leak private repo/agent data | Use origin-bound secure storage, configured/replace semantics, revoke/reauth flows, redacted logs/UI, minimal lock-screen copy, and no private defaults | AF-008, privacy hardening / AF-006-E,F | **OPEN** |
| AF6-G011 | P1 | `live/loading/empty/error` is defined mainly for Home; other screens lack auth, rate, partial, stale, closed, merged and delivery failure states; a merged sample appears under “Open Pull Requests” | Define Open versus Recent scope, then implement and test the required state families below per screen/tab; never convert transport/parsing failure into empty/idle | AF-006-C–G | **OPEN** |
| AF6-G012 | P1 | Online/idle/working/stale/offline and Forgejo/agent health are conflated; heartbeat samples are display strings | Keep connection, capability, heartbeat TTL, work-claim freshness and source provenance separate; expose absolute accessible timestamps | AF-005 / AF-006-C,E | **PARTIAL** |
| AF6-G013 | P1 | README/prototype navigation and state model disagree; current app uses independent routes, not a persistent shell | Adopt an indexed Home/Summary/Agents/Settings shell, push PR/Agent Detail routes above it, preserve cold/warm deep links and per-destination state | AF-006-C | **DECIDED — IMPLEMENT** |
| AF6-G014 | P1 | Quick chips overwrite drafts; Enter behavior is desktop-biased; auto-grow is promised but absent; timers/autoscroll can target the wrong message | Preserve/insert draft text, scope drafts/typing/scroll/delivery to full PR identity, define IME/send behavior, keyboard avoidance, size limits and near-bottom autoscroll | AF-006-D | **OPEN** |
| AF6-G015 | P1 | Fixed pixels and horizontal strips do not specify safe areas, small/large devices, landscape, 200% text, long code/names or localization | Use platform safe areas and adaptive layouts; define wrap/truncate/scroll rules; test 200% text, long/localized strings, keyboard and landscape | AF-006-B–G | **OPEN** |
| AF6-G016 | P1 | Tertiary/quaternary copy, human bubble, working fill and avatar foreground fail sampled WCAG AA; some states rely on color | Replace failing values with semantic accessible tokens; pair color with text/icon; validate contrast in all enabled/disabled/focus states | AF-006-B,G | **PARTIAL** — Flutter does not reproduce the opacity-token failures (no `.45`/`.40` alpha text). Avatar contrast remains a real bug: `foregroundFor()` uses brightness estimation, not WCAG luminance — mid-brightness agent colors can get white text at 2.17:1. Working fill / human bubble not yet implemented. Fix in progress for avatar contrast via `foregroundFor()`. |
| AF6-G017 | P1 | Notification toggles omit OS denied/provisional state, delivery architecture, background behavior, privacy and deep-link failure | Define platform permission states, minimal preview policy, routing, disabled reasons, background delivery, revoke/error and test matrix | AF-006-F | **OPEN** |
| AF6-G018 | P1 | Summary lacks metric definitions, repository scope, freshness, timezone, accessibility values, pagination/cache and partial-data rules | Specify formulas/attribution/source/timezone, paginated/ETag data plan, updated time, accessible table alternative, empty/error/partial states | AF-006-F / AF-005 | **OPEN** |
| AF6-G019 | P1 | Permission, pause and remove actions mutate optimistically with no confirmation, acknowledgement, audit, rollback or recovery | Define authorized idempotent commands, confirmation by risk, server ACK/pending/failure, audit entry, token revoke and recovery/undo policy | AF-004/005 / AF-006-E | **BLOCKED** |
| AF6-G020 | P1 | Connection test and notification/permission saves only simulate success | Model saving/testing/saved/rejected/timeout/offline/auth-expired states and rollback; test `/version` and `/user` with typed latency/result | AF-006-E | **OPEN** |
| AF6-G021 | P1 | Conversation attribution can rely on spoofable body markers; code/timestamps/links/edit/delete states are incomplete | Use authenticated Forgejo/bot identity, stable comment IDs/permalinks, absolute times, safe markdown/code handling and edited/deleted states | AF-003/004 / AF-006-D | **OPEN** |
| AF6-G022 | P1 | Offline/cache/partial-failure behavior and stale-data age are unspecified across screens | Define cache boundary, age display, retry/cancel, per-endpoint partial results, pagination failure and read-only behavior when stale | AF-005 / AF-006-C–F | **OPEN** |
| AF6-G023 | P1 | Handoff says dark-only while platform/theme behavior and high-contrast mode are not decided | Decide dark-only release scope versus system theme; in either case support platform contrast/text settings and semantic colors | AF-006-B | **DECISION NEEDED** |
| AF6-G024 | P1 | Prototype loads pinned React/ReactDOM/Babel from `unpkg`, evaluates generated JSX, lacks reproducible source/license/CSP, and was not runtime-verified in the main browser | Do not ship/host it. If retained later, sanitize, license, vendor/lock runtime, add CSP, rebuild instructions and isolated non-production hosting | AF-006-A2 / AF-008 | **BLOCKED** |
| AF6-G025 | P2 | Infinite pulse/blink and toggle motion have no reduced-motion behavior; haptics are unspecified | Tie motion to real state, provide reduced/no-motion variants, avoid invented activity, and define optional platform haptics | AF-006-B,G | **OPEN** |
| AF6-G026 | P2 | No canonical portrait/golden/semantics matrix or integration-test suite exists | Add state-complete portrait references, deterministic fixtures, golden baselines, semantics tests and device CUJs for every work row | AF-006-A2,G | **OPEN** |
| AF6-G027 | P2 | Labels such as “Local Agents,” “Why,” relative-only times and ambiguous review chips can mislead | Use “Agent endpoints,” “Rationale summary,” absolute accessible time, explicit destinations and action-specific safety copy | AF-006-C–F | **OPEN** |

### Evidence behind `PARTIAL`

| Gap | Existing shipped foundation | Still missing |
|---|---|---|
| AF6-G004 | `lib/core/forgejo/forgejo_providers.dart::PrKey` scopes providers by owner/repo/number and formal review rechecks `headSha`; `lib/core/agents/agent_models.dart::AgentEntry.id` is a local UUID | Stable Forgejo instance, endpoint/host and persisted full-PR identities across every model/action |
| AF6-G007 | `lib/core/mcp/mcp_client.dart::sendFeedback` keeps `clientMessageId`, sends an idempotency key, rejects ambiguous retries and requires `deliveryId`; `lib/core/mcp/mcp_models.dart::FeedbackResult` exposes both IDs | Durable lifecycle persistence/subscription, Forgejo-versus-agent reconciliation, per-leg partial failure and correlated replies |
| AF6-G012 | `lib/core/agents/agent_models.dart::AgentWorkItem` requires active state plus a fresh `updatedAt`; `agent_providers.dart::agentWorkProvider` expires cached claims; `agent_work_client.dart` keeps unavailable distinct from idle | Stable endpoint health/capabilities, absolute heartbeat provenance and complete per-endpoint UI states |

### AF-006-B contrast correction inputs

Ratios use WCAG 2.1 sRGB relative luminance. Opacity-based text colors are
first composited over `color.background.card` (`#1C1C1E`). These source values
are measurements, not approved replacement tokens.

| Source token / pair | Ratio | AA result for normal text | Required AF-006-B disposition |
|---|---:|---|---|
| `color.text.tertiary` on card | 3.93:1 | Fail | Raise to ≥4.5:1; default small metadata to the secondary semantic token |
| `color.text.quaternary` on card | 3.40:1 | Fail | Do not use for readable 11–12sp copy |
| `color.text.primary` on `color.humanBubble` | 3.65:1 | Fail | Darken the bubble (audit candidate `#0070DF`) or change foreground |
| `color.text.primary` on `color.accent.greenFill` | 4.40:1 | Fail | Darken fill (audit candidate about `#21833A`) before normal white text |
| White initials on `agents.Claude/Codex/Grok/Gemini` | 2.65 / 2.17 / 2.61 / 3.27:1 | Fail | Use computed dark/light foreground from `color_contrast.dart`; never hard-code white |
| White initials on `agents.custom` | 5.06:1 | Pass | Still use computed foreground so custom colors remain safe |

## Screen-to-Flutter pickup map

| Target surface | Current code | Honest starting state | Primary gaps / dependency |
|---|---|---|---|
| Theme/tokens | `lib/core/theme/app_theme.dart`, `color_contrast.dart` | Partial semantic dark theme and dynamic avatar foreground | G008, G015, G016, G023; AF-006-B |
| App shell | `lib/router.dart` | Independent routes; deep links work | G013; AF-006-C must preserve cold/warm routing |
| Home connection/PR list | `lib/features/home/home_screen.dart` | Open PR list, refresh, All/With Agents, basic empty/error/partial state | G011, G012, G022; pagination and typed health |
| Home endpoint carousel | agent providers only | No visual carousel | AF-005 health/provenance; AF-006-C |
| PR header and tabs | `lib/features/pr_detail/pr_detail_screen.dart` | One long page; exact-head review guard exists | G004–G007; AF-003/004/005; AF-006-D |
| Conversation/composer | PR detail plus `agent_context_panel.dart` | Forgejo review/comment and separate MCP feedback composers | G007, G014, G021; converge only after transport decision |
| Agent Context | `agent_context_panel.dart`, MCP providers | Strong endpoint-bound/fresh-claim foundation | Preserve authored rationale, provenance and updated time |
| Commits/Changes/checks | none | Absent | G006; AF-003 first |
| Agents | `lib/features/agents/agents_screen.dart` | Manual local CRUD | G003, G009, G012, G019; AF-004/005 |
| Agent Detail | none | Absent | AF-004/005 then AF-006-E |
| Settings | `lib/features/settings/settings_screen.dart` | URL/token save, test, disconnect | G010, G017, G020; AF-006-E/F |
| Summary | none | Absent | G018; AF-006-F |
| Coordination | `lib/features/coordination/coordination_screen.dart` | Existing internal surface | Keep as secondary/internal route; do not confuse with Summary |

## Required state families

Every touched screen must explicitly map relevant states to copy, controls,
semantics, retry policy and test coverage.

| Domain | Required states |
|---|---|
| Forgejo connection | unconfigured, loading, connected, auth-expired, forbidden, rate-limited, TLS/redirect rejected, offline, retrying, partial, disconnecting |
| Pull request | loading, draft, open, closed-unmerged, merged, checks pending/failing/passing, conflict, unmergeable, head-changed, permission-lost, stale/cached |
| Agent endpoint | unconfigured, pairing, online-idle, online-working, stale, offline, auth-expired, incompatible capability/version, paused, revoked, failed, retrying |
| Feedback | draft, sending, queued, delivered, processing, replied, failed-retryable, failed-terminal, ambiguous-write, destination-changed |
| Pairing | idle, minting, ready-with-TTL, copied, waiting, registered, expired, rejected, duplicate, cancelled, revoked, network error |
| Async collection | loading, empty, ready, partial, stale, cached-offline, page-error, terminal-error |
| Settings mutation | unchanged, dirty, validating, saving, saved, rejected, timeout, rolled-back, reauthentication-required |
| Notifications | undetermined, provisional, authorized, denied, disabled-in-system, unavailable, registering, registered, delivery-error |

## Decisions and non-negotiable constraints

- Flutter remains the implementation stack. The stale React Native prompt is
  not part of the intake.
- Formal review remains a Forgejo action pinned to the exact head. Merge is not
  a chat shortcut and AF-006 adds no unreviewed merge permission.
- Forgejo remains the source of truth for Git state and formal review. Agent
  endpoints supply fresh, authored status/context and an authenticated feedback
  delivery channel; they never supply hidden chain-of-thought.
- Remote endpoint traffic remains authenticated HTTPS; loopback HTTP remains
  development-only.
- Four top-level destinations are the provisional target: Home, Summary,
  Agents, Settings. PR and Agent Detail are pushed routes above the shell.
- AF-004 must decide central broker versus direct sidecars before AF-006-E.
- AF-008 must decide asset/runtime provenance and public licensing before
  AF-006-A2.
- Dark-only versus system theme, Summary metric definitions, and notification
  delivery/privacy policy remain product decisions (G023/G018/G017).

## Pickup protocol

1. Pull first with `git pull --ff-only`, then read this tracker,
   `docs/10-Mobile-Design-Handoff-Review.md`, the tracked intake README, and
   `docs/AGENT_MCP_CONTRACT.md`.
2. Select the first unblocked ledger row. If none remains after AF-006-A1,
   advance the named upstream decision/gate in its owning tracker or decision
   PR; do not start a blocked visual control by inventing its product or backend
   contract.
3. Fetch and branch explicitly from remote `main`; stage only explicit files.
4. Add a testable acceptance matrix for every screen/state touched. Preserve
   deep-link, trusted-origin, HTTPS, freshness and exact-head safeguards.
5. Update this row, all affected gap statuses, and the changelog in the same
   implementation PR. Link the ready-for-review Forgejo PR.
6. Run the repository's full format/analyze/test/coverage/build gates and the
   row-specific golden/semantics/device checks. Record what was and was not
   physically verified.

## Definition of Done

AF-006 can move to **DONE** only when:

- [ ] Every ledger row AF-006-A1 through AF-006-G is shipped or explicitly
  removed by a recorded superseding decision.
- [ ] No P0 gap is open or merely waived without an accepted safety decision.
- [ ] Sanitized canonical visual assets have provenance, correct MIME, unique
  state captures and verified hashes; no private host/token/repository text is
  present in text or OCR.
- [ ] The shell, Home, PR Detail, Conversation, Context, Changes, Activity,
  Agents, Agent Detail, Settings, Summary and pairing flows meet their complete
  state matrices.
- [ ] Review and feedback target exact stable identities; head changes
  invalidate review; no conversational or unreviewed merge control exists.
- [ ] Pairing, endpoint actions and delivery use authenticated, idempotent,
  acknowledged contracts with durable observable state.
- [ ] WCAG 2.1 AA contrast, semantic controls, 44dp targets, 200% text,
  keyboard order, reduced motion, VoiceOver and TalkBack flows are verified.
- [ ] Golden/semantics tests, the full Flutter suite, non-regressing coverage,
  Android build and Web build pass; required Android/iOS device CUJs are
  recorded honestly.
- [ ] Forgejo `main` and the GitHub mirror contain the same shipped commits,
  tracker links and archived completion record.
- [ ] Completion claims are verified against shipped code, inbound references
  are updated, and this tracker is moved to `docs/archives/past_projects/` with
  its decision lineage preserved.

## Changelog

- **2026-07-18 — G005/G016 staleness fix:** G005 resolved in code (Flutter never
  carried unsafe merge language from prototype). G016 evidence clarified:
  opacity-token failures not reproduced in Flutter; avatar contrast via
  `foregroundFor()` is the remaining known bug. Both reflect discovery from
  full lib/ codebase audit.

- **2026-07-18 — AF-006-A1 SHIPPED:** Forgejo #4 merged reviewed head
  `c65f8e46c6b8d07860222081b7ad4ec7d7842988` non-forced as
  [`8b10705f`](https://github.com/avidullu/agentforge/commit/8b10705f3e5252441a8b7beb3e991e3699a270d5).
  Exact-head CI passed formatting, fatal-info analysis, 46 tests, 35.92% line
  coverage against the 29% floor, Android debug APK and release Web build.
  Forgejo and GitHub `main` were then verified identical; downstream rows stay
  blocked on their recorded decisions and contracts.
- **2026-07-18 — Forgejo #4 review addressed:** Removed new private-host PR
  URLs, made the three `PARTIAL` statuses traceable to shipped symbols, added
  operational AF-006-B contrast inputs, and changed the manifest recipe from a
  hash listing to an assertion against the recorded digest. The PR description
  now reports all eight ledger rows.
- **2026-07-18 — AF-006-A1 IN REVIEW:** Selected the owner's exact Final
  handoff; inventoried all 24 files; audited all 14 images and prototype/code
  artifacts; tracked the disclosure-safe visual tokens plus exact source
  hashes; quarantined private, broken and provenance-unclear binaries; mapped
  the handoff to the existing Flutter code; created the PR-sized ledger, gap
  register, state matrix, pickup protocol and Definition of Done. Runtime
  interaction was not verified in the main in-app browser because local
  `file://` navigation was blocked by browser policy. Local verification:
  relative links, JSON parsing, all 24 source hashes, binary quarantine,
  denylist scan and `git diff --check` passed; formatting changed 0/39 files;
  Flutter analysis was clean; all 46 tests passed at 573/1595 lines (35.92%,
  floor 29%); debug APK and release Web builds succeeded. Published as
  ready-for-review Forgejo #4 on the owner instance.
