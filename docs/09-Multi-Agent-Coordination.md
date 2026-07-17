# Multi-Agent & Multi-Machine Coordination

**Core requirement**

The app must make it easy to:
1. See which PRs each local coding agent is currently working on.
2. Connect / relate work happening on the **same repository** across multiple machines/agents.

## Goals

- Any agent can report “I am currently working on these PRs / this branch”.
- The mobile app shows a clear picture of active work per agent and per repository.
- User can easily link related efforts across machines.

## Recommended Approach

### Agent-side (MCP)

Expose:

- Resource / tool: `work/list` or `resource://active-work`
  ```json
  [
    {
      "repo": "owner/repo",
      "pr_number": 42,
      "branch": "feature/auth-middleware",
      "title": "Implement auth middleware",
      "status": "in_progress",
      "updated_at": "..."
    }
  ]
  ```

### App-side

- Home + Agents screens show “Currently working on” per agent.
- Repo-centric view shows all agents active on that repo.
- PR Detail shows “Related work on other machines” when applicable.

## Principle

Keep it lightweight. The app is a visibility + light coordination layer. Source of truth remains Git + Forgejo.
