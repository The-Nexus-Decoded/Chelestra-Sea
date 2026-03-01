# Chelestra-Sea — The Realm of Water

**Layer:** Networking & Communication  
**Org:** [The-Nexus-Decoded](https://github.com/The-Nexus-Decoded)

Fleet communication, cross-agent integration, and Lobster workflow orchestration for the OpenClaw homelab.

## The Nexus Decoded

<pre>
The-Nexus-Decoded/
├── Pryan-Fire/          — Business logic, agent services, tools
├── <b>Chelestra-Sea/</b>       — Networking, communication, integration          ◀ you are here
├── Arianus-Sky/         — UIs, dashboards, visualizations
├── Abarrach-Stone/      — Data, schemas, storage
└── Nexus-Vaults/        — Workspace snapshots, fleet docs
</pre>

## Structure

```
Chelestra-Sea/
├── workflows/              # Lobster workflow files (.lobster)
│   ├── seventh-gate        # Safe gateway restart
│   ├── pryan-forge         # PR review monitor
│   ├── nexus-bridge        # Full PR lifecycle
│   ├── chelestra-tide      # Post-update patch reapply
│   ├── labyrinth-watch     # Issue triage dashboard
│   ├── abarrach-seal       # Stale branch cleanup
│   ├── sartan-cipher       # Workspace sync
│   ├── chelestra-current   # Fleet maintenance
│   ├── abarrach-stone      # Memory consolidation
│   ├── patryn-workhorse    # CI pipeline (build + test)
│   └── ...                 # Agent-specific wrappers
├── fleet/                  # Fleet CLI extensions, cross-server tooling
├── integrations/           # Discord bots, webhooks, API bridges
└── docs/                   # Integration specs, protocol docs
```

## Lobster Workflows

| Workflow | What | Used by |
|----------|------|---------|
| seventh-gate | Safe gateway restart | All agents |
| pryan-forge | PR scan + report | Zifnab |
| nexus-bridge | Full PR lifecycle (branch, commit, push, create, merge) | Haplo |
| chelestra-tide | Post-update patch reapply | Zifnab |
| labyrinth-watch | Issue triage dashboard | Zifnab |
| abarrach-seal | Stale branch cleanup | Zifnab |
| sartan-cipher | Workspace vault sync | Zifnab |
| chelestra-current | Fleet maintenance report | Zifnab |
| abarrach-stone | Memory consolidation review | Zifnab |
| patryn-workhorse | Build + test runner | Haplo |
