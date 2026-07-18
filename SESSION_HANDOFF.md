# AgentForge repository ramp-up pointer

This file exists for tools that look for an in-repository handoff. The living
handoff is stored at:

```text
C:\Users\avidu\OneDrive\Documents\claude-sync\memory\Agentforge\session-handoff.md
```

Read in this order:

1. [`docs/08-Implementation-Plan-and-Milestones.md`](docs/08-Implementation-Plan-and-Milestones.md)
2. [`docs/10-Mobile-Design-Handoff-Review.md`](docs/10-Mobile-Design-Handoff-Review.md)
3. [`docs/AGENT_MCP_CONTRACT.md`](docs/AGENT_MCP_CONTRACT.md)
4. [`docs/DEEP_LINKING.md`](docs/DEEP_LINKING.md)
5. The files named by the shared handoff's current ramp-up kit

Repository conventions:

- Forgejo `origin` is canonical; GitHub `github` is the mirror.
- Pull with `git pull --ff-only` before reading.
- Branch explicitly from current `origin/main` and publish ready-for-review PRs
  unless a draft is explicitly requested.
- Every implementation PR updates its tracker row and changelog.
- Verify Forgejo/GitHub `main` parity after merges.
