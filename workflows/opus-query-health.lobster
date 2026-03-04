name: opus-query-health
description: "Check opus query pipeline health. Tests SSH to Windows, queue status, zombie PIDs, session state. Pure CLI, zero LLM calls."
steps:
  - id: check
    description: "Check opus pipeline health"
    command: |
      bash /data/openclaw/scripts/shared/opus-query-health.sh
    timeoutMs: 30000
