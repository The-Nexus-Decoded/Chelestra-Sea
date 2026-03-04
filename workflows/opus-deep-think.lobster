name: opus-deep-think
description: "Escalate a task to Claude Opus for deep reasoning. Queue-managed, one-at-a-time fleet-wide. All usage logged."
args:
  prompt:
    description: "The question or task for Opus"
    type: string
  reason:
    description: "Why Opus is needed: research | architecture | analysis | stuck | owner-requested | review"
    type: string
  agent:
    description: "Which agent is requesting (zifnab, haplo, hugh)"
    type: string
    default: "zifnab"
steps:
  - id: check_limits
    description: "Show today's usage before proceeding"
    command: |
      /data/openclaw/scripts/shared/opus-queue.sh limits "$(hostname)"
    timeoutMs: 15000

  - id: run_query
    description: "Execute opus query with queue management (waits if another query is active)"
    command: |
      /data/openclaw/scripts/private/opus-query.sh --reason "${reason}" "${prompt}"
    timeoutMs: 300000

  - id: show_status
    description: "Show updated queue status after query"
    command: |
      /data/openclaw/scripts/shared/opus-queue.sh status
    timeoutMs: 15000
