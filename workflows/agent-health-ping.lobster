name: agent-health-ping
description: "Check agent liveness across the fleet. Checks gateway health, service status, last activity. Pure CLI, zero LLM calls."
steps:
  - id: ping
    description: "Ping all agents"
    command: |
      bash /data/openclaw/scripts/shared/agent-health-ping.sh
    timeoutMs: 30000
