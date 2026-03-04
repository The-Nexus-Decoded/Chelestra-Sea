# Fleet Deployment Guide

## Overview

This document describes the deployment architecture for the OpenClaw fleet and how to manage Lobster workflow distribution across all servers.

## Architecture Summary

### Servers (Tailscale Network)

| Server | Tailscale IP | Role | Primary Agent |
|--------|--------------|------|---------------|
| ola-claw-main | 100.103.189.117 | Coordinator | Zifnab |
| ola-claw-dev | 100.94.203.10 | Development | Haplo |
| ola-claw-trade | 100.104.166.53 | Trading | Hugh |

### Repository Structure (The-Nexus-Decoded org)

| Repository | Purpose | Key Directories |
|------------|---------|-----------------|
| **Pryan-Fire** | Business logic, agent code | `haplos-workshop/`, `hughs-forge/`, `zifnabs-scriptorium/` |
| **Chelestra-Sea** | Infrastructure, workflows, integration | `workflows/`, `fleet/`, `integrations/`, `docs/` |
| **Arianus-Sky** | UIs, dashboards | `apps/`, `dashboards/`, `shared/` |
| **Abarrach-Stone** | Data, schemas, ML | `schemas/`, `pipelines/`, `archives/` |
| **Nexus-Vaults** | Workspace backups, fleet docs | `ola-claw-main/`, `ola-claw-dev/`, `ola-claw-trade/`, `scripts/`, `docs/` |

### Critical Concept: Two distinct "workspace" directories

1. **Agent Workspace** (runtime): `/data/openclaw/workspace/`
   - Local to each server
   - Contains: SOUL.md, MEMORY.md, memory/, workflows/
   - Used by gateway to load agent personality, memory, and available Lobster pipelines
   - **This is what agents execute from**

2. **Version-Controlled Workspace Snapshot** (backup): `/data/repos/Nexus-Vaults/ola-claw-{main,dev,trade}/`
   - Centralized in GitHub (Nexus-Vaults repo)
   - Redacted before commit (no secrets)
   - Served as backup and audit trail
   - Populated by `sartan-cipher.lobster` (or `workspace-sync.lobster`)

## Lobster Workflow Lifecycle

### Development Phase

1. Create/modify workflow files in **Chelestra-Sea/workflows/**
2. Test locally on development server (ola-claw-dev) by copying to `/data/openclaw/workspace/workflows/`
3. Commit and push branch to GitHub
4. Open PR, get review, merge to `main` of Chelestra-Sea

### Deployment Phase (the missing piece)

**Current State:** There is no automated deployment. Workflows must be manually copied from the repository to each server's runtime directory.

**Required Manual Steps:**

```bash
# On ola-claw-main (Zifnab)
cd /data/repos/Chelestra-Sea
git pull origin main
cp -v workflows/*.lobster /data/openclaw/workspace/workflows/
# Verify
ls -1 /data/openclaw/workspace/workflows/*.lobster | wc -l
```

Repeat for ola-claw-dev and ola-claw-trade (or use SSH to automate).

### Best Practice: Synchronize After Every Merge

Any time Chelestra-Sea/main is updated with new workflows:
1. Pull the changes on ola-claw-main
2. Copy all `.lobster` files to `/data/openclaw/workspace/workflows/`
3. SSH to ola-claw-dev and ola-claw-trade and repeat

**Alternative:** Set up a cron job or use the fleet CLI to distribute.

## Current Fleet State (2026-03-04)

### Workflow Count by Server

| Server | Total workflows | In sync with Chelestra-Sea? |
|--------|-----------------|----------------------------|
| ola-claw-main | 26 | ❌ Partial |
| ola-claw-dev | 31 | ❌ Partial |
| ola-claw-trade | 30 | ❌ Partial |

### Discrepancies

- **Only on dev:** `memory-guard.lobster`, `orchestrator-pulse.lobster`
- **Only on trade:** `death-gate-fleet-sync.lobster`, `fleet-status.lobster`, `hughs-forge-deploy.lobster`
- **Only on main:** `legacy-issues-migration.lobster`
- **Missing on dev:** `legacy-issues-migration.lobster`, `hughs-forge-deploy.lobster`
- **Missing on trade:** `legacy-issues-migration.lobster`

**Action:** Bring all servers to parity by copying the full set from Chelestra-Sea/main to each server.

## Backup Process (Already Implemented)

`sartan-cipher.lobster` (Chelestra-Sea#??) performs:
- Change detection using file hashes
- Copy of SOUL.md, MEMORY.md, memory/*.md, workflows/*.lobster from `/data/openclaw/workspace/` to a temp dir
- Redaction of secrets (API keys, tokens, IPs)
- Commit + push to Nexus-Vaults/main
- Requires approval before push

**Schedule:** Run daily or whenever significant changes are made.

**Note:** This backs up the **runtime** workspace to the repository. It does NOT deploy from repository to runtime.

## CI/CD Pipelines

GitHub Actions workflows are defined in `.github/workflows/` in each repository.

### Key CI/CD Flows

| Workflow | Repository | Triggers | Purpose |
|----------|------------|----------|---------|
| `deploy-mvp.yml` | Pryan-Fire | push to main | Deploy Haplo's combined_runner to Hugh's server (ola-claw-trade) |
| `test-pr.yml` | Pryan-Fire | PR opened/updated | Run phantom-gauntlet test suite |
| (others) | Various | | |

**Important:** CI/CD pipelines themselves are not versioned in the same way as Lobster workflows; they live in the `.github/workflows/` directory of each repo and deploy automatically via GitHub Actions.

## Deployment Checklist

When making changes to a Lobster workflow:

- [ ] Develop in Chelestra-Sea/workflows/
- [ ] Test by manually copying to relevant server(s)
- [ ] Commit and push branch
- [ ] Open PR and get approval
- [ ] Merge to main
- [ ] **Deploy to all servers:** Pull Chelestra-Sea/main and copy workflows to `/data/openclaw/workspace/workflows/`
- [ ] Verify on each server: `lobster --list` shows the new/updated workflow
- [ ] If the workflow is agent-specific, ensure it's only on that agent's server (or document why it's on all)
- [ ] Run backup via `sartan-cipher.lobster` to snapshot the updated runtime state

## Open Questions / TODOs

1. **Automated Deployment:** Should we create a `workflow-deploy.lobster` that pulls Chelestra-Sea/main and distributes to all servers automatically?
2. **Agent-Specific Workflows:** Some workflows are clearly for specific agents (haplo-*, zifnab-*, hughs-*). Should they only exist on that agent's server? Or should all agents have all workflows?
3. **Version Pinning:** If servers diverge, which version is "correct"? Need a process to reconcile.
4. **Documentation Sync:** Keep this DEPLOYMENT.md up to date with actual practice.

## Useful Commands

```bash
# List workflows on current server
ls -1 /data/openclaw/workspace/workflows/*.lobster | xargs -n1 basename

# Compare workflows between servers
comm -12 <(ssh openclaw@100.94.203.10 "ls -1 /data/openclaw/workspace/workflows/*.lobster" | xargs -n1 basename | sort) <(ls -1 /data/openclaw/workspace/workflows/*.lobster | xargs -n1 basename | sort)

# Copy all workflows from repo to current server
cd /data/repos/Chelestra-Sea && git pull origin main
cp -v workflows/*.lobster /data/openclaw/workspace/workflows/

# Copy from current server to another server (e.g., push to dev)
scp /data/openclaw/workspace/workflows/*.lobster openclaw@100.94.203.10:/data/openclaw/workspace/workflows/
```

## Glossary

- **Runtime workspace:** The live `/data/openclaw/workspace/` on each server where agents operate
- **Nexus-Vaults:** The backup repository that stores redacted snapshots of each agent's workspace
- **Chelestra-Sea:** The infrastructure repository containing canonical workflow definitions
- **Sartan Cipher:** The backup workflow (synchronizes runtime → vault)
- **Seventh Gate:** The safe restart workflow
- **Lobster:** The workflow runtime engine

---

*Last updated: 2026-03-04 by Zifnab*