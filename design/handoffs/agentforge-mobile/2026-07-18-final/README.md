# AgentForge mobile design intake — 2026-07-18

**Status:** TRACKED INTAKE INDEX / VISUAL BINARIES QUARANTINED

**Canonical tracker:**
[`docs/projects/AF-006-Mobile-Design-Ingestion.md`](../../../../docs/projects/AF-006-Mobile-Design-Ingestion.md)

**Supporting audit:**
[`docs/10-Mobile-Design-Handoff-Review.md`](../../../../docs/10-Mobile-Design-Handoff-Review.md)

This package is the reproducible, Git-tracked intake index for the selected
local handoff at
`App building assistance/Final-App building assistance/design_handoff_agentforge_mobile`.
It preserves exact source identity, classifications, and the disclosure-safe
visual token datum without promoting private screenshots, prototype code,
sample infrastructure, or draft API text into the public repository.

## Precedence

When two artifacts disagree, use this order:

1. Shipped code and the normative repository security/protocol documents,
   especially `docs/AGENT_MCP_CONTRACT.md` and the tracked project ledger.
2. Accepted decisions and closed gaps in the AF-006 tracker.
3. Source screenshots `01`–`09` for visual direction only, after AF-006-A2
   clears provenance and disclosure gates and imports sanitized derivatives.
4. `tokens.visual-source.json` for source measurements, after accessibility
   correction and Flutter semantic-token mapping.
5. Source screenshots `10`–`11` and concept mocks as provenance/evidence only.

The source README's “pixel-perfect/final” label does not override safety,
accessibility, platform behavior, or the existing Flutter architecture.
Unspecified behavior remains an open tracker gap; implementers must not invent
it silently.

## Tracked artifacts

| Path | Classification | Use |
|---|---|---|
| `README.md` | intake policy | Precedence, quarantine, and pickup rules |
| `SOURCE-MANIFEST.md` | provenance index | Exact hashes, dimensions, content types, and exclusions |
| `tokens.visual-source.json` | exact source datum | Measurement input only; several colors fail WCAG AA |

## Quarantined visual catalog

The following files remain in the owner-provided local source and are not in
Git. Their exact hashes are recorded in `SOURCE-MANIFEST.md`.

| Path | Classification | Use |
|---|---|---|
| `screenshots/01-home.png` | visual baseline | Home hierarchy and card direction |
| `screenshots/02-pr-conversation.png` | visual baseline | PR header, tabs, conversation, composer |
| `screenshots/03-pr-agent-context.png` | visual baseline | Authored plan/rationale and recent activity |
| `screenshots/04-pr-commits.png` | incomplete baseline | Commit list direction; not a review surface |
| `screenshots/05-pr-files.png` | incomplete baseline | File-summary direction; diff/checks remain required |
| `screenshots/06-summary.png` | visual baseline | Summary hierarchy; metric definitions are unresolved |
| `screenshots/07-agents.png` | visual baseline | Endpoint list direction |
| `screenshots/08-agent-detail.png` | unsafe baseline | Layout reference only; unreviewed-merge control is prohibited |
| `screenshots/09-settings.png` | incomplete baseline | Settings grouping; credential/privacy flows unresolved |
| `screenshots/10-add-agent-sheet.png` | defective evidence | Identical to `11`; the sheet content is not visible |
| `screenshots/11-pairing.png` | defective evidence | Identical to `10`; pairing states are not specified |
| source `mocks/` | concept lineage | Composition inspiration only; not pixel or copy acceptance |

The binaries are quarantined because screenshots `01`, `08`, and `09` expose
private namespace/host details; `10` and `11` are broken duplicates; the three
concept files are JPEG payloads mislabeled as PNG; and the frame/generated
asset provenance has no source URL or license. AF-006-A2 must sanitize,
regenerate, provenance-clear, MIME-correct, and hash the canonical derivatives
before they enter Git history.

## Deliberately excluded from Git

- All source screenshots and concept mocks until AF-006-A2 clears the gates
  above.
- The raw HTML prototype and `support.js`: private host/sample values, unsafe
  merge behavior, CDN-loaded React/Babel runtime, and no production semantics.
- `ios-frame.jsx`: presentation shell, not app code.
- `mock-data.json`: private infrastructure examples and non-normative data
  identities.
- `types.ts`: design-only identities and delivery types conflict with the
  shipped exact-PR/endpoint/idempotency model.
- `CLAUDE-CODE-PROMPT.md`: assumes a new React Native app instead of this
  repository's existing Flutter app.
- Prototype `docs/agentforge-mcp.md` and `docs/forgejo-api.md`: hard-coded
  private infrastructure and claims that conflict with the normative repo
  contract.

These files are hash-recorded so a future redaction/provenance decision can be
made without losing source identity. They must not be copied into production
code or documentation as authoritative text.

## Pickup sequence

1. Read the AF-006 tracker and choose the first unblocked work row.
2. Read `docs/10-Mobile-Design-Handoff-Review.md` and the normative MCP
   contract before using any visual or copy.
3. Resolve every gap assigned to that row in the same PR; update the row and
   tracker changelog.
4. Map visual values to semantic Flutter tokens. Do not import the source JSON
   directly.
5. Add widget/golden/semantics tests for all touched states, then run the full
   repository verification gates.

No implementation PR is complete merely because one screenshot looks similar.
Safety states, accessibility, long-content behavior, failure handling, and
device acceptance are part of the design.
