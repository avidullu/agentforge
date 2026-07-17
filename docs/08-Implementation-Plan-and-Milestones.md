# AgentForge — Implementation Plan & Milestone Execution

**Goal**: Build the app in small, shippable increments so that after every milestone we can install it on a real phone and run a concrete Critical User Journey (CUJ).

## Core Technical Decisions

| Area | Decision | Reason |
|------|----------|--------|
| Framework | Flutter (stable) | Single codebase iOS + Android |
| State | Riverpod 2.x | Simple, testable |
| Networking | dio | Clean interceptors |
| Secure storage | flutter_secure_storage | Tokens |
| Deep linking | app_links | Universal / App Links |
| MCP client | Thin custom over Streamable HTTP | Full control |
| Forgejo client | Thin hand-written | Only needed endpoints |
| Navigation | go_router | Deep-link friendly |

## Milestone Plan

### Milestone 0 — Skeleton + Deep Link Ready
- Flutter project with correct package name
- Basic Material 3 dark theme
- go_router + app_links wired
- Placeholder Home
- Deep link handler that receives a PR URL

**On-device CUJ**: Open a Forgejo PR link from Gmail → app opens and shows the received link.

### Milestone 1 — Forgejo Connection + PR List
- Settings for instance URL + PAT
- Real list of open PRs from Tailscale Forgejo

### Milestone 2 — PR Detail + Formal Reviews
- Conversation, comment, Approve / Request Changes

### Milestone 3 — Agent Registry + Status + Active Work
- Register local agents
- Show which PRs each agent is working on
- Agent origin badges on PRs

### Milestone 4 — Agent Context Panel (MCP)
- Live plan, reasoning, send feedback to agent

### Milestone 5 — Polish + Multi-machine Coordination View

## Execution Rule
After every milestone: build → install on phone → run the defined CUJ → only then proceed.
