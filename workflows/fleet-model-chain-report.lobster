name: fleet-model-chain-report
description: "Show model chains and rate-guard config across all servers. Pure CLI, zero LLM calls."
steps:
  - id: report
    description: "Report model chains fleet-wide"
    command: |
      bash /data/openclaw/scripts/shared/fleet-model-chain-report.sh
    timeoutMs: 30000
