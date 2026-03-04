name: orchestrator-pulse
description: "Fleet health check and status report. Pure CLI via fleet commands, no LLM needed."
steps:
  - id: health
    description: "Check fleet health"
    command: |
      fleet health --json
    timeoutMs: 15000

  - id: prs
    description: "Check open PRs"
    command: |
      fleet pr-scan --json
    timeoutMs: 30000

  - id: agents
    description: "Check agent liveness"
    command: |
      fleet agent-ping --json
    timeoutMs: 15000

  - id: report
    description: "Format combined report"
    command: |
      echo "=== Fleet Health ==="
      echo "$HEALTH_JSON" | fleet format 2>/dev/null || echo "(raw output above)"
      echo ""
      echo "=== Open PRs ==="
      echo "$PRS_JSON" | fleet format 2>/dev/null || echo "(raw output above)"
      echo ""
      echo "=== Agent Liveness ==="
      echo "$AGENTS_JSON" | fleet format 2>/dev/null || echo "(raw output above)"
    timeoutMs: 10000
