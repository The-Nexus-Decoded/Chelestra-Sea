name: context-size-monitor
description: "Monitor agent session file sizes. Flags sessions approaching context limits. Pure CLI, zero LLM calls."
steps:
  - id: monitor
    description: "Check session sizes across fleet"
    command: |
      bash /data/openclaw/scripts/shared/context-size-monitor.sh
    timeoutMs: 30000
