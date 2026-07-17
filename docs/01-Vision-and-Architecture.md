# AgentForge Mobile App — Vision & Architecture

**Personal-use iOS + Android app** for reviewing PRs on a Tailscale-connected Forgejo instance, with deep integration to local coding agents (Claude, Codex, Gemini, Grok, etc.) via the Model Context Protocol (MCP).

## Core Goals

1. **Deep-link from Gmail** → open the exact PR in the app.
2. **Identify the originating local agent/machine** clearly and reliably.
3. **Rich agent context** — not just the Git diff, but the agent’s plan, reasoning, recent actions, and ability to inject feedback.
4. **Lightweight formal review actions** (comment, approve, request changes) via Forgejo API.
5. Fully private (everything stays inside the Tailscale tailnet).
6. **Multi-machine coordination** — easily see and relate work on the same repo across different agents/machines.

## High-Level Architecture

```
Mobile App (Flutter)
    │
    ├── Tailscale ──► Forgejo (source of truth for PRs, reviews, merge)
    │
    └── Tailscale ──► Local Agent MCP Servers
                       (one per machine / agent instance)
                       Claude / Codex / Gemini / Grok / custom wrappers
```

- **Forgejo** remains the system of record for Git state and formal reviews.
- **MCP servers** running alongside the agents provide the rich, live context and control surface.

## Key Design Decisions

- Cross-platform: Flutter (single codebase).
- Networking: Tailscale only (no public exposure).
- Protocol for agents: Model Context Protocol (MCP) over Streamable HTTP.
- Configuration: Explicit agent registry + optional discovery.
- UI philosophy: Dense but readable, dark-mode first, agent identity always visible.
