# Mobile design handoff review

**Reviewed:** 2026-07-18

**Source:** local `App building assistance/design_handoff_agentforge_mobile/`

**Status:** visual direction is strong; interaction, safety, state, and
accessibility specifications are not implementation-final.

## Material reviewed

- `README.md` and `CLAUDE-CODE-PROMPT.md`
- `AgentForge App.dc.html` (interactive-prototype source)
- `ios-frame.jsx`
- Three PNG screen mocks

The HTML bundle references a missing `support.js`, so it is not runnable as the
promised local interactive prototype outside its original design runtime. The
PNG mocks and prototype also differ materially; where they conflict, the
handoff says the prototype wins. Obsolete mocks should be watermarked or
archived before implementation.

## What is working well

- The dashboard prioritizes fleet status and actionable PRs in a useful order.
- Agent and host identity repeat across the dashboard, PR detail, and registry.
- Working, idle, offline, open, and review-requested states have text as well as
  color.
- Conversation is correctly treated as a primary PR-detail workflow.
- Sending → delivered-to-host → reply is the right trust model for remote work,
  once backed by correlated transport events.
- Plan, rationale, commits, and files are conceptually separated.
- System typography, restrained iOS-dark surfaces, and 16-18px radii form a
  coherent native-mobile direction.
- Code syntax colors measured well, with the weakest sampled pair at 7.43:1.

## Screen and component map

| Screen | Main components | Product action |
|---|---|---|
| Home | Header, Forgejo health, endpoint carousel/cards, PR cards, agent/host badges, navigation | Open a PR |
| PR detail | Target header, PR state, endpoint state, tab control | Review and coordinate |
| Conversation | Messages, code snippet, delivery receipt, quick actions, composer | Send feedback |
| Agent context | Plan, rationale disclosure, recent-action timeline | Understand intent |
| Changes | File rows and counts | Inspect code; currently incomplete |
| Activity | Commits and events | Understand history |
| Agents | Forgejo connection, endpoint rows, add/edit actions | Pair and manage endpoints |

Recommended reusable primitives:

- `SafeAreaScreen`, `AppTabBar`, `SectionHeader`, `EmptyState`, `ErrorState`
- `ConnectionStatus`, `EndpointIdentity`, `EndpointStatusCard`
- `PullRequestCard`, `PullRequestStateBadge`, `PullRequestHeader`
- `PRTabBar`, `ChangesList`, `DiffViewer`, `ChecksSummary`
- `ConversationList`, `MessageBubble`, `DeliveryReceipt`, `FeedbackComposer`
- `ContextCard`, `RationaleDisclosure`, `TimelineRow`, `AgentRegistryRow`

## Critical product and safety findings

### 1. There is no real code-review surface

The Files view shows only path and addition/deletion counts; commits are also
non-interactive. A user cannot inspect the code that an Approve action would
approve.

Required improvement:

- Rename Files to Changes.
- Open unified or split diffs with line numbers and viewed state.
- Support line selection/commenting and a Forgejo fallback.
- Show checks, conflicts, mergeability, draft state, base/head branches, exact
  head SHA, approval summary, and whether the current user is requested.

### 2. Destructive review/merge language is too casual

“LGTM, merge it” appears alongside benign text macros. Merge must be a separate
privileged flow. It should show the exact instance/repository/PR/head, required
checks and approvals, conflicts, permissions, merge method, and a final
confirmation. Until those gates exist, remove the macro.

### 3. Connectivity and activity are conflated

The prototype can show a pulsing live chip for a PR whose sample endpoint is
offline. “Online,” “idle,” “working,” “stale,” and “unreachable” are different
states. Forgejo health and agent transport health are also independent.

Required model:

- `lastHeartbeatAt`, `lastSuccessfulPollAt`, and a documented TTL.
- Loading, online-idle, online-working, stale, offline, auth-expired, rate
  limited, failed, and retrying.
- Queued feedback when supported, with a clear statement of where it is queued.
- Never turn a network/parsing failure into “no active work.”

### 4. Routing identities are not stable enough

PR numbers repeat across repositories and Forgejo instances. Display names
repeat across agent endpoints. The implementation target is:

- PR: `{forgeInstanceId, owner, repo, number, headSha}`
- endpoint: `{agentEndpointId, hostId}` plus display name
- message: `clientMessageId`
- delivery: `deliveryId`, correlated to exactly one message and endpoint

### 5. Prototype receipt logic is race-prone

The prototype's delayed callbacks mutate “the last message” and later re-read
the current PR. A rapid second send or navigation can update/reply to the wrong
message or PR. Timers must be replaced with adapter-driven, per-message events;
pending work must remain scoped to its PR and endpoint.

### 6. Agent context can leak or target the wrong endpoint

The initial Flutter implementation queried every MCP-enabled endpoint whenever
any PR opened. Context and feedback should default only to endpoints explicitly
claiming or linked to that PR. Selecting another endpoint must be a visible user
action with the destination shown before send.

## Interaction and state gaps

- Loading, skeleton, empty, partial-error, auth-expired, rate-limit, retry,
  closed, merged, conflict, no-endpoint, and delivery-failure states are absent.
- Agent setup needs pairing/authentication, capability/version check, test
  connection, rename, revoke/delete, duplicate handling, and clear trust copy.
- “Local Agents” is misleading for remote/cloud hosts; use “Agent endpoints” or
  “Registered agents.”
- Context needs provenance and an updated time. Do not display raw
  chain-of-thought; request an authored “Why this change?” rationale summary.
- Relative times need an accessible absolute timestamp.
- Code blocks need path/language, line numbers, copy, and horizontal handling.
- Auto-scroll only when the reader is near the bottom; otherwise show a new
  messages affordance.
- Safe areas, keyboard avoidance, long hostnames, localization, and Dynamic
  Type can overflow the fixed layouts.
- Consider PR tabs in the order Conversation → Changes → Context → Activity.

## Accessibility audit

This was a source/visual audit, not a VoiceOver or TalkBack runtime test.

| Sample | Contrast | WCAG AA result |
|---|---:|---|
| Primary white on card | 17.01:1 | Pass |
| Secondary text on card | 5.94:1 | Pass |
| Tertiary `.45` on card | 3.93:1 | Fail at small size |
| Micro `.40` on card | 3.40:1 | Fail |
| Working-card task text | 3.19:1 | Fail |
| White on working fill | 4.40:1 | Slight fail for normal text |
| White on blue human bubble | 3.65:1 | Fail |
| Green status on card | 8.42:1 | Pass |
| White avatar initials | 2.17-3.27:1 on sampled agent colors | Fail |
| White on custom purple | 5.06:1 | Pass |
| Syntax colors on code background | 7.43-12.19:1 | Pass |

Corrections:

- Raise small/tertiary copy to at least the current `.6` secondary token.
- Do not reduce the opacity of an entire offline card.
- Darken the working fill to about `#21833A` with opaque white text.
- Darken a white-text human bubble to about `#0070DF`.
- Compute dark/light avatar foreground from the chosen background.
- Give the composer a visible `#6D6D72` boundary and green focus ring.
- Make back, send, chips, Edit, tabs, and icon actions at least 44×44dp.
- Add names, roles, selected/expanded state, focus visibility, and polite live
  announcements for delivery state changes.
- Verify 200% text, external keyboard order, reduced motion, switch control,
  VoiceOver, and TalkBack.

## Handoff inconsistencies

- README promises ≥44px targets, but back (34), send (36), chips, Edit, and tabs
  are smaller.
- README promises an auto-growing composer, but the prototype has no height
  update logic.
- README says a quick action prefixes a draft; the prototype replaces it and
  discards unsent text.
- README says the HTML can be opened interactively, but `support.js` is absent.
- “Final/pixel-perfect” conflicts with missing state, review, safety, and
  accessibility specs. Use “visual direction final; interaction and
  accessibility specification in progress.”

## Prioritized implementation plan

### P0 — before presenting AgentForge as a review/control app

1. Stable Forgejo, PR-head, endpoint, message, and delivery identities.
2. Changes/diff/checks/mergeability flow and stale-head invalidation.
3. Remove/gate merge macros and show exact mutation targets.
4. Authenticated HTTPS endpoint model with heartbeat/error/freshness states.
5. Correlated, adapter-driven feedback receipts with no ambiguous retries.
6. Semantic controls, 44dp targets, contrast corrections, and safe layouts.

### P1 — first usable release

1. Endpoint onboarding/pairing/edit/revoke and explicit PR association.
2. Full loading/empty/error/offline/auth-expired/device states.
3. Safe-area, keyboard, Dynamic Type, and non-disruptive auto-scroll behavior.
4. Instance, repository, branches, head, checks, and review ownership in the
   persistent PR header.
5. Tabs and lazy/collapsed agent context so conversation and changes stay near.

### P2 — polish

1. Search/filter/sort, unread state, notifications, and offline cache.
2. Message timestamps/permalinks, code copy, viewed files, line-linked feedback.
3. Haptics, reduced-motion variants, localization stress tests.
4. A packaged runnable prototype and component/state matrix.

## Changes already initiated by AF-001

- System-font, dark-token theme; no runtime Google Fonts fetch.
- Trusted HTTPS deep-link authority and single app-links owner.
- Formal reviews target an exact head SHA and recheck it before submission.
- PR context is no longer broadcast to every registered endpoint.
- Feedback gains client/delivery IDs and is not retried across transports after
  an ambiguous write.
- Remote side-car URLs require HTTPS; loopback HTTP remains for the local mock.
- Active work requires an active status and a fresh heartbeat.
- Avatar foreground and review action layout start the accessibility pass.

These are foundations, not completion of the P0/P1 list.
